#!/usr/bin/env python3
import os
import sys
from pathlib import Path
from typing import Iterable, Dict
import subprocess as sp

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


def read_lexicon(lexicon_path: Path) -> Iterable[Dict]:
    lexicon = []
    with lexicon_path.open() as lex_f:
        for line in lex_f:
            fields = line.strip().split("\t")
            lexicon.append({
                "native": fields[0],
                "roman": fields[1],
                "prons": fields[2:]
            })
    return lexicon


def create_langdir(args):
    dictdir = args.dst / "local" / "dict_{}".format(args.lang)
    langdir = args.dst / "lang_{}".format(args.lang)

    subset = "build"
    for d in (dictdir, langdir):
        if d.exists() and not args.overwrite:
            raise OSError("Directory {} exists, not overwriting!")
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
        "reference_materials" / "lexicon.txt")
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
            for pron in lexeme["prons"]:
                # TOOD(rkjaran): Not sure how we'll handle the phones in
                #                other_phones. Remove them for now.
                for phone in other_phones:
                    pron = pron.replace(phone, "")
                print("{} {}".format(word, pron), file=kaldilex_f)
                nonsilence_phones.update(pron.split())

    with (dictdir / "nonsilence_phones.txt").open('w') as nonsil_f:
        for phone in nonsilence_phones:
            print(phone, file=nonsil_f)

    with (dictdir / "silence_phones.txt").open('w') as sil_f:
        for phone in silence_phones:
            print(phone, file=sil_f)

    with (dictdir / "optional_silence.txt").open('w') as optsil_f:
        for phone in optional_silence:
            print(phone, file=optsil_f)

    (dictdir / "extra_questions.txt").touch()

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
