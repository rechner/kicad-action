# kicad-action

GitHub Action to automate KiCad tasks, e.g. check ERC/DRC on pull requests or
generate production files for releases.

## Features

- Run Electrical Rules Check (ERC) on schematic
- Run Design Rules Check (DRC) on PCB
- Generate PDF and BOM from schematic
- Generate Gerbers ZIP from PCB
- Generate raytraced board images

## Example

```yaml
on: [push]

jobs:
  kicad_job:
    runs-on: ubuntu-latest
    name: My KiCad job
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Export production files
        id: production
        uses: rechner/kicad-action@main
        if: '!cancelled()'
        with:
          kicad_sch: my-project.kicad_sch
          sch_pdf: true # Generate PDF
          sch_bom: true # Generate BOM
          kicad_pcb: my-project.kicad_pcb
          pcb_gerbers: true # Generate Gerbers

      - id: info
        env:
          GITHUB_SHA: ${{ github.sha }}
        run: |
          echo "now=$(date +'%Y-%m-%dT%H-%M-%S')" >> $GITHUB_ENV >> $GITHUB_OUTPUT
          echo "sha_short=${GITHUB_SHA::7}" >> $GITHUB_ENV >> $GITHUB_OUTPUT

      # Upload production files only if generation succeeded
      - name: Upload production files
        uses: actions/upload-artifact@v4
        if: ${{ !cancelled() && steps.production.conclusion == 'success' }}
        with:
          name: PawprintTarget-${{ steps.info.outputs.sha_short }}-${{ steps.info.outputs.now }}
          path: |
            ${{ github.workspace }}/schematics/sch.pdf
            ${{ github.workspace }}/schematics/bom.csv
            ${{ github.workspace }}/schematics/gbr.zip

      - name: Run KiCad ERC
        id: erc
        uses: rechner/kicad-action@main
        if: '!cancelled()'
        with:
          kicad_sch: my-project.kicad_sch
          sch_erc: true

      - name: Run KiCad DRC
        id: drc
        uses: rechner/kicad-action@main
        if: '!cancelled()'
        with:
          kicad_pcb: my-project.kicad_pcb
          pcb_drc: true

      - name: Annotate
        if: always()
        env:
          ERC_FILE: ${{ github.workspace }}/schematics/erc.rpt
          DRC_FILE: ${{ github.workspace }}/schematics/drc.rpt
        run: |
          cat >> $GITHUB_STEP_SUMMARY <<EOF
          ### Build Summary :rocket:
          For \`${{ steps.info.outputs.sha_short }}\`, built at \`${{ steps.info.outputs.now }}\`
          | Job | Status | Summary |
          | --- | ------ | ------- |
          EOF
          if [[ ${{ steps.erc.outputs.erc_violation }} -eq 0 ]]; then
            echo "| ERC | ✅ Pass | |" >> $GITHUB_STEP_SUMMARY
          else
            echo "| ERC | ❌ Fail | ${{ steps.erc.outputs.erc_message }} |" >> $GITHUB_STEP_SUMMARY
          fi
          if [[ ${{ steps.drc.outputs.drc_message }} -eq 0 ]]; then
            echo "| DRC | ✅ Pass | |" >> $GITHUB_STEP_SUMMARY
          else
            echo "| DRC | ❌ Fail | ${{ steps.drc.outputs.drc_message }} |" >> $GITHUB_STEP_SUMMARY
          fi
          cat >> $GITHUB_STEP_SUMMARY <<EOF
          <details>
          <summary>ERC Report</summary>
          <pre>
          EOF
          cat $ERC_FILE >> $GITHUB_STEP_SUMMARY
          cat >> $GITHUB_STEP_SUMMARY <<EOF
          </pre>
          </details>
          <details>
          <summary>DRC Report</summary>
          <pre>
          EOF
          cat $DRC_FILE >> $GITHUB_STEP_SUMMARY
          cat >> $GITHUB_STEP_SUMMARY <<EOF
          </pre>
          </details>
          EOF
      # Upload ERC report only if ERC failed
      - name: Upload ERC report
        uses: actions/upload-artifact@v4
        if: ${{ failure() && steps.erc.conclusion == 'failure' }}
        with:
          name: erc-${{ steps.info.outputs.sha_short }}-${{ steps.info.outputs.now }}.rpt
          path: ${{ github.workspace }}/schematics/erc.rpt

      # Upload DRC report only if DRC failed
      - name: Upload DRC report
        uses: actions/upload-artifact@v4
        if: ${{ failure() && steps.drc.conclusion == 'failure' }}
        with:
          name: drc-${{ steps.info.outputs.sha_short }}-${{ steps.info.outputs.now }}.rpt
          path: ${{ github.workspace }}/schematics/drc.rpt
```

See this example working in the action runs of this repository.

## Configuration

| Option             | Description                                     | Default                      |
|--------------------|-------------------------------------------------|------------------------------|
| `kicad_sch`        | Path to `.kicad_sch` file                       |                              |
| `sch_erc`          | Whether to run ERC on the schematic             | `false`                      |
| `sch_erc_file`     | Output filename of ERC report                   | `erc.rpt`                    |
| `sch_pdf`          | Whether to generate PDF from schematic          | `false`                      |
| `sch_pdf_file`     | Output filename of PDF schematic                | `sch.pdf`                    |
| `sch_bom`          | Whether to generate BOM from schematic          | `false`                      |
| `sch_bom_file`     | Output filename of BOM                          | `bom.csv`                    |
| `sch_bom_preset`   | Name of a BOM preset setting to use             |                              |
| `report_format`    | ERC/DRC report file format (`json` or `report`) | `report`                     |
|                    |                                                 |                              |
| `kicad_pcb`        | Path to `.kicad_pcb` file                       |                              |
| `pcb_drc`          | Whether to run DRC on the PCB                   | `false`                      |
| `pcb_drc_file`     | Output filename for DRC report                  | `drc.rpt`                    |
| `pcb_gerbers`      | Whether to generate Gerbers from PCB            | `false`                      |
| `pcb_gerbers_file` | Output filename of Gerbers                      | `gbr.zip`                    |
| `pcb_image`        | Whether to render the PCB image                 | `false`                      |
| `pcb_image_path`   | Where to put the top.png and bottom.png         | `images`                     |
| `pcb_model`        | Whether to export the PCB model                 | `false`                      |
| `pcb_model_file`   | Output filename of PCB model                    | `pcb.step`                   |
| `pcb_model_flags`  | Flags to add when exporting STEP files          | see [action.yml](action.yml) |

## Roadmap

- [ ] Add support for more configuration options, e.g. BOM format or Gerber layers
- [ ] Add a way to specify KiCad version to use
- [ ] Better detect if steps of this action fail
- [ ] Find a better way to enforce the default output files extensions depending on the format requesed

## Contributing

Contributions, e.g. in the form of issues or pull requests, are greatly appreciated.
