"""
This file takes the provided GBD Cause Map and rearranges to enable searching
by ICD code for each category.
"""

import csv


def make_icd_ranges(icd_codes: str) -> list[tuple[str, str]]:
    icd_codes_list = icd_codes.split(", ")
    icd_ranges = []
    for icd_codes in icd_codes_list:
        if "-" in icd_codes:
            start, end = icd_codes.split("-")
        else:
            start = end = icd_codes
        icd_ranges.append((start, end))

    return icd_ranges


def main():
    for icd_version in ("9", "10"):
        with open("gbd-icd-map-with-levels.csv", encoding="utf-8-sig") as gbd_map, open(
            f"icd{icd_version}-map.csv", "w", encoding="utf-8-sig"
        ) as icd_map:
            reader = csv.DictReader(gbd_map)

            fieldnames = ["ICD_Start", "ICD_End", "Cause", "Level"]
            icd_writer = csv.DictWriter(icd_map, fieldnames=fieldnames)
            icd_writer.writeheader()

            for row in reader:
                cause = row["Cause"]
                icd_codes = row[f"ICD{icd_version}"]
                level = row["Level"]

                icd_ranges = make_icd_ranges(icd_codes)
                for start, end in icd_ranges:
                    icd_writer.writerow(
                        {
                            "ICD_Start": start,
                            "ICD_End": end,
                            "Cause": cause,
                            "Level": level,
                        }
                    )


if __name__ == "__main__":
    main()
