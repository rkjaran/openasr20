#!/usr/bin/env python3
import os
import sys
from pathlib import Path
from typing import Iterable, Dict
import subprocess as sp
import re

def parse_args():
    import argparse
    parser = argparse.ArgumentParser(
        description="Prepare langdir for OpenASR2020",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument("--corpus-dir", required=True, type=Path,
                        help="Path to OpenASR2020 corpus")
    parser.add_argument("--lang", required=True,
                        help="Language to use, e.g. openasr20_amharic")
    parser.add_argument("--dst", required=True, type=Path,
                        help="Top level destination. Will create langdir as subdir.")
    parser.add_argument("--use-roman", action='store_true', default=False,
                        help="Use the romanized lexicon/transcripts to create "
                        "the langdir")
    parser.add_argument("--overwrite", action='store_true', default=False)

    return parser.parse_args()


def has_roman(corpus_dir: Path, lang: Path) -> bool:
    return (corpus_dir / lang / "build" / "transcription_roman").exists()


def read_lexicon(lexicon_path: Path, roman=False) -> Iterable[Dict]:
    lexicon = []
    with lexicon_path.open() as lex_f:
        for line in lex_f:
            fields = line.strip().split("\t")
            if roman:
                lexicon.append({
                    "native": fields[0],
                    "roman": fields[1],
                    "prons": fields[2:]
                })
            else:
                lexicon.append({
                    "native": fields[0],
                    "prons": fields[1:]
                })
    return lexicon


def create_langdir(args):
    dictdir = args.dst / "local" / "dict_{}".format(args.lang)
    langdir = args.dst / "lang_{}".format(args.lang)

    subset = "build"
    for d in (dictdir, langdir):
        if d.exists() and not args.overwrite:
            raise OSError("Directory {} exists, not overwriting!".format(d))
        d.mkdir(parents=True, exist_ok=True)

    silence_phones = {"sil", "spn"}
    optional_silence = {"sil"}
    other_phones = {
        "#",                    # syllable break
        "."                     # word boundary
    }
    nonsilence_phones = set()
    lexicon = read_lexicon(
        args.corpus_dir / args.lang / subset /
        "reference_materials" / "lexicon.txt",
        roman=has_roman(args.corpus_dir, args.lang)
    )
    phone_with_tag_regex = re.compile(r'^(.+)(_[A-Z0-9"])$')
    # TOOD(rkjaran): move to arguments?
    # additional_spn = [
    #     "<breath>",
    #     "<click>",
    #     "<cough>",
    #     "<dtmf>",
    #     "<hes>",
    #     "<int>",
    #     "<laugh>",
    #     "<lipsmack>",
    #     "<overlap>",            # perhaps not?
    #     "<sta>",
    # ]
    with (dictdir / "lexicon.txt").open('w') as kaldilex_f:
        print("<unk> spn", file=kaldilex_f)
        for lexeme in lexicon:
            word = lexeme["roman"] if args.use_roman else lexeme["native"]
            # The phonetic transcriptions can include a tag, e.g. for tone.
            # So, for Kaldi we have to map the source pron line
            #     Ban	b_< a: n _1	b_< a: N _1
            # to
            #     Ban	b_<_1 a:_1 n_1
            #     Ban	b_<_1 a:_1 N_1
            # and add the stress marked phonemes to extra_questions.txt, like so:
            #    b_<b_<_1
            printed_pron_lines = set()
            try:
                for pron in lexeme["prons"]:
                    new_pron_syllables = []
                    syllable_index = 0
                    syllable_has_stress = False
                    for phone in pron.split():
                        tag_match = re.match(r'_["0-9A-Z]', phone)
                        if tag_match:
                            new_pron_syllables[syllable_index] = \
                                [p + tag_match.group(0) for p in
                                 new_pron_syllables[syllable_index]]
                        elif phone == '"': # stress marker
                            # apply to phones until we hit syl/word boundary
                            syllable_has_stress = True
                        elif phone == "." or phone == "#":
                            syllable_index += 1
                            syllable_has_stress = False
                        else:
                            phone += '_"' if syllable_has_stress else ""
                            if len(new_pron_syllables) == syllable_index:
                                new_pron_syllables.append([phone])
                            else:
                                new_pron_syllables[syllable_index].append(phone)
                    new_pron = [ x for y in new_pron_syllables for x in y ]

                    # # TOOD(rkjaran): Not sure how we'll handle the phones in
                    # #                other_phones. Remove them for now.
                    # for phone in other_phones:
                    #     pron = pron.replace(phone, "")
                    new_pron_line = "{} {}".format(word, " ".join(new_pron))
                    if new_pron_line not in printed_pron_lines:
                        nonsilence_phones.update(new_pron)
                        printed_pron_lines.add(new_pron_line)
                        print(new_pron_line, file=kaldilex_f)

            except:
                print(lexeme)
                raise
    with (dictdir / "nonsilence_phones.txt").open('w') as nonsil_f:
        for phone in nonsilence_phones:
            print(phone, file=nonsil_f)

    with (dictdir / "silence_phones.txt").open('w') as sil_f:
        for phone in silence_phones:
            print(phone, file=sil_f)

    with (dictdir / "optional_silence.txt").open('w') as optsil_f:
        for phone in optional_silence:
            print(phone, file=optsil_f)

    with (dictdir / "extra_questions.txt").open('w') as extra_f:
        questions = dict()
        for phone in nonsilence_phones:
            base_phone = re.sub(phone_with_tag_regex, r"\1", phone)
            if base_phone in questions:
                questions[base_phone].add(phone)
            else:
                questions[base_phone] = {phone}
        for key, q in questions.items():
            print(" ".join(sorted(q)), file=extra_f)

    sp.check_call(
        "utils/prepare_lang.sh {dictdir} '{unk_symbol}' {tmpdir} {langdir}"
        .format(dictdir=dictdir, unk_symbol="<unk>",
                tmpdir=args.dst / "local" / "lang_{}".format(args.lang),
                langdir=langdir),
        shell=True
    )


def main():
    args = parse_args()
    create_langdir(args)


if __name__ == '__main__':
    main()
