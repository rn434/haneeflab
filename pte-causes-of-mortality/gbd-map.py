"""
This file combines data from the GBD ICD map and the GBD level map to create
one file with all of the data available.
"""

import csv


def main():
    with open("gbd-icd-map.csv", encoding="utf-8-sig") as icd_map, open(
        "gbd-level-map.csv", encoding="utf-8-sig"
    ) as level_map, open(
        "gbd-icd-map-with-levels.csv", "w", encoding="utf-8-sig"
    ) as combined:
        icd_reader = csv.DictReader(icd_map)
        level_reader = csv.DictReader(level_map)

        fieldnames = ["Cause", "ICD10", "ICD9", "Level"]
        combined_writer = csv.DictWriter(combined, fieldnames=fieldnames)
        combined_writer.writeheader()

        levels_dict = {}
        for row in level_reader:
            cause = row["Cause"]
            level = int(row["Level"])
            if cause in levels_dict:
                raise Exception("Duplicate cause in gbd-level-map.csv!")
            levels_dict[cause] = level

        for row in icd_reader:
            cause = row["Cause"]
            icd10 = row["ICD10"]
            icd9 = row["ICD9"]
            level = levels_dict.get(cause, None)
            combined_writer.writerow(
                {
                    "Cause": cause,
                    "ICD10": icd10,
                    "ICD9": icd9,
                    "Level": level,
                }
            )


if __name__ == "__main__":
    main()
