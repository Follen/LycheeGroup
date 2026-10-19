"""Package separate Chinese and English defaults for LycheeFont.

Source versions, download links and licenses are in
addon/LycheeGroup/Media/Fonts/README.md. Requires fontTools.
"""

import argparse
from pathlib import Path
from shutil import copyfile
from tempfile import TemporaryDirectory

from fontTools import subset
from fontTools.merge import Merger
from fontTools.ttLib import TTFont
from fontTools.ttLib.scaleUpem import scale_upem
from fontTools.varLib.instancer import instantiateVariableFont


def regular_font(path, axes):
    font = TTFont(path)
    if "fvar" in font:
        font = instantiateVariableFont(font, axes, inplace=True)
    # The addon renders horizontal UI text; vertical positioning tables do not
    # apply to the Latin component and cannot be merged between these families.
    for tag in ("BASE", "DSIG", "vhea", "vmtx", "VORG"):
        if tag in font:
            del font[tag]
    return font


def build_english(chinese_source, inter, output):
    han = regular_font(chinese_source, {"wght": 400})
    latin = regular_font(inter, {"wght": 400, "opsz": 14})
    chinese_copyright = han["name"].getDebugName(0) or ""
    chinese_license = han["name"].getDebugName(13) or ""
    chinese_family = han["name"].getDebugName(1) or chinese_source.stem
    embedding = han["OS/2"].fsType | latin["OS/2"].fsType
    chinese_metrics = {
        "hhea": {key: getattr(han["hhea"], key)
                 for key in ("ascent", "descent", "lineGap")},
        "OS/2": {key: getattr(han["OS/2"], key)
                 for key in ("sTypoAscender", "sTypoDescender", "sTypoLineGap",
                             "usWinAscent", "usWinDescent")},
    }
    chinese_typo_metrics = han["OS/2"].fsSelection & (1 << 7)
    scale_upem(latin, han["head"].unitsPerEm)
    expected = set(han.getBestCmap()) | set(latin.getBestCmap())

    # Only the English UI uses this file. Inter supplies Latin, Greek and
    # Cyrillic; CJK glyphs keep player names and game text readable.
    options = subset.Options()
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.glyph_names = True
    chinese = subset.Subsetter(options=options)
    chinese.populate(unicodes=set(han.getBestCmap()) - set(latin.getBestCmap()))
    chinese.subset(han)

    with TemporaryDirectory(prefix="lycheefont-") as temporary:
        files = [Path(temporary) / "latin.ttf", Path(temporary) / "han.ttf"]
        latin.save(files[0])
        han.save(files[1])
        font = Merger().merge([str(path) for path in files])

    # Merger otherwise expands these to Inter's taller metrics. Preserve the
    # source Chinese font's size and baseline at the addon's existing sizes.
    for tag, metrics in chinese_metrics.items():
        for key, value in metrics.items():
            setattr(font[tag], key, value)
    font["OS/2"].fsSelection = (font["OS/2"].fsSelection & ~(1 << 7)) | chinese_typo_metrics

    names = font["name"]
    for name_id, text in {
        0: chinese_copyright + " Copyright 2016 The Inter Project Authors.",
        1: "LycheeFont English", 2: "Regular", 3: "LycheeFont-English-1.2",
        4: "LycheeFont English", 5: "Version 1.200", 6: "LycheeFont-English",
        8: "LycheeFont composition. Chinese source: " + chinese_family + ". Latin: Inter.",
        16: "LycheeFont English", 17: "Regular", 21: "LycheeFont English", 22: "Regular",
        13: "Chinese source terms: " + chinese_license + " "
            "Inter is licensed under the SIL Open Font License, Version 1.1. "
            "See the accompanying README and source license notices; "
            "this composition does not grant additional rights to the Chinese font.",
        14: "",
    }.items():
        names.removeNames(nameID=name_id)
        names.setName(text, name_id, 3, 1, 0x409)
    for name_id in (1, 4, 16, 21):
        names.setName("荔枝字体英文版", name_id, 3, 1, 0x804)
    font["OS/2"].usWeightClass = 400
    font["OS/2"].fsType = embedding
    font["head"].macStyle = 0
    font["head"].created = font["head"].modified = 3875126400
    font.recalcTimestamp = False
    assert not (expected - set(font.getBestCmap())), "merged font lost encoded characters"
    assert "fvar" not in font, "the bundled font must be static"
    output.parent.mkdir(parents=True, exist_ok=True)
    font.save(output)
    print(f"{output}: {output.stat().st_size:,} bytes; "
          f"{len(font.getBestCmap()):,} codepoints; {len(font.getGlyphOrder()):,} glyphs")


def build(chinese_source, inter, output_directory):
    output_directory.mkdir(parents=True, exist_ok=True)
    chinese_output = output_directory / "LycheeFont-zhCN.ttf"
    # Preserve every Chinese-source character, including digits and Latin,
    # plus all metrics and hinting. Never merge Inter into the Chinese file.
    copyfile(chinese_source, chinese_output)
    print(f"{chinese_output}: {chinese_output.stat().st_size:,} bytes; unchanged Chinese source")
    build_english(chinese_source, inter, output_directory / "LycheeFont-enUS.ttf")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chinese", required=True, type=Path)
    parser.add_argument("--inter", required=True, type=Path)
    parser.add_argument("--output-directory", required=True, type=Path)
    args = parser.parse_args()
    build(args.chinese, args.inter, args.output_directory)
