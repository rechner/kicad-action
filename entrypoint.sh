#!/bin/bash

set -e

mkdir -p $HOME/.config
cp -r /home/kicad/.config/kicad $HOME/.config/

erc_violation=0 # ERC exit code
drc_violation=0 # DRC exit code

# Temporary file to capture summary output
kicad_out=/tmp/kicad-cli.out

# Run ERC if requested
if [[ -n $INPUT_KICAD_SCH ]] && [[ $INPUT_SCH_ERC = "true" ]]
then
  kicad-cli sch erc \
    --output "`dirname $INPUT_KICAD_SCH`/$INPUT_SCH_ERC_FILE" \
    --format $INPUT_REPORT_FORMAT \
    --exit-code-violations \
    "$INPUT_KICAD_SCH" | tee "$kicad_out"
    erc_violation=${PIPESTATUS[0]}
    echo "erc_message=`grep ^Found $kicad_out`" >> "$GITHUB_OUTPUT"
    echo "erc_violation=$erc_violation" >> "$GITHUB_OUTPUT"
fi

# Export schematic PDF if requested
if [[ -n $INPUT_KICAD_SCH ]] && [[ $INPUT_SCH_PDF = "true" ]]
then
  kicad-cli sch export pdf \
    --output "`dirname $INPUT_KICAD_SCH`/$INPUT_SCH_PDF_FILE" \
    "$INPUT_KICAD_SCH"
fi

# Export schematic BOM if requested
if [[ -n $INPUT_KICAD_SCH ]] && [[ $INPUT_SCH_BOM = "true" ]]
then
  kicad-cli sch export bom \
    --output "`dirname $INPUT_KICAD_SCH`/$INPUT_SCH_BOM_FILE" \
    --preset "$INPUT_SCH_BOM_PRESET" \
    "$INPUT_KICAD_SCH"
fi

# Run DRC if requested
if [[ -n $INPUT_KICAD_PCB ]] && [[ $INPUT_PCB_DRC = "true" ]]
then
  kicad-cli pcb drc \
    --output "`dirname $INPUT_KICAD_PCB`/$INPUT_PCB_DRC_FILE" \
    --format $INPUT_REPORT_FORMAT \
    --exit-code-violations \
    "$INPUT_KICAD_PCB" | tee "$kicad_out"
  drc_violation=${PIPESTATUS[0]}
  echo "drc_message=`cat $kicad_out | tr '\n' ' '`" >> "$GITHUB_OUTPUT"
  echo "drc_violation=$drc_violation" >> "$GITHUB_OUTPUT"
fi

# Export Gerbers if requested
if [[ -n $INPUT_KICAD_PCB ]] && [[ $INPUT_PCB_GERBERS = "true" ]]
then
  GERBERS_DIR=`mktemp -d`
  kicad-cli pcb export gerbers \
    --output "$GERBERS_DIR/" \
    "$INPUT_KICAD_PCB"
  kicad-cli pcb export drill \
    --output "$GERBERS_DIR/" \
    "$INPUT_KICAD_PCB"
  zip -j \
    "`dirname $INPUT_KICAD_PCB`/$INPUT_PCB_GERBERS_FILE" \
    "$GERBERS_DIR"/*
fi

if [[ -n $INPUT_KICAD_PCB ]] && [[ $INPUT_PCB_IMAGE = "true" ]]
then
  mkdir -p "`dirname $INPUT_KICAD_PCB`/$INPUT_PCB_IMAGE_PATH"
  kicad-cli pcb render --side top \
    --output "`dirname $INPUT_KICAD_PCB`/$INPUT_PCB_IMAGE_PATH/top.png" \
    "$INPUT_KICAD_PCB"
  kicad-cli pcb render --side bottom \
    --output "`dirname $INPUT_KICAD_PCB`/$INPUT_PCB_IMAGE_PATH/bottom.png" \
    "$INPUT_KICAD_PCB"
fi

if [[ -n $INPUT_KICAD_PCB ]] && [[ $INPUT_PCB_MODEL = "true" ]]
then
  kicad-cli pcb export step $INPUT_PCB_MODEL_FLAGS \
    --output "`dirname $INPUT_KICAD_PCB`/$INPUT_PCB_MODEL_FILE" \
    "$INPUT_KICAD_PCB"
fi

echo "Generating annotations for messages"
echo "erc_message=$erc_message"
echo "drc_message=$drc_message"

# Generate Github Action annotations for failed ERC or DRC violations
if [[ $erc_violation -gt 0 ]]; then
  echo "::error title=ERC Violation::$erc_message"
  echo "::error file=$INPUT_KICAD_SCH,line=1::ERC Violation"
fi
if [[ $drc_violation -gt 0 ]]; then
  echo "::error title=DRC Violation::$drc_message"
  echo "::error file=$INPUT_KICAD_PCB,line=1::DRC Violation"
fi

# Return non-zero exit code for ERC or DRC violations
if [[ $erc_violation -gt 0 ]] || [[ $drc_violation -gt 0 ]]
then
  exit 1
else
  exit 0
fi
