import csv
import sys
from pathlib import Path
from typing import Literal


def determine_icd_version(icd_code: str) -> Literal[9, 10]:
    if icd_code[0].isdigit():
        return 9
    return 10


def clean_icd_code(icd_code: str, icd_version: Literal[9, 10]) -> str:
    if icd_version == 10:
        if len(icd_code) >= 4:
            return f"{icd_code[0:3]}.{icd_code[3:]}"
        return icd_code
    else:
        raise NotImplementedError()


def map_to_causes(icd_code: str, icd_dict: dict[tuple, str]) -> list:
    causes = ["", "", "", ""]
    for current_level in ["1", "2", "3", "4"]:
        for icd_start_end_level, cause in icd_dict.items():
            icd_start, icd_end, level = icd_start_end_level
            if level != current_level:
                continue
            if icd_start < icd_code < icd_end:
                causes[int(level) - 1] = cause
                break
    return causes


def csv_to_dict(filepath: Path) -> dict[tuple, str]:
    with open(filepath, encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        icd_to_cause = {}
        for row in reader:
            icd_start = row["ICD_Start"]
            icd_end = row["ICD_End"]
            cause = row["Cause"]
            level = row["Level"]

            icd_to_cause[(icd_start, icd_end, level)] = cause

    return icd_to_cause


def main():
    current_path = Path(__file__).parent
    icd9_dict = csv_to_dict(current_path / "icd9-map.csv")
    icd10_dict = csv_to_dict(current_path / "icd10-map.csv")

    if len(sys.argv) > 1:
        filepath = sys.argv[1]
        try:
            with open(filepath) as f:
                reader = csv.DictReader(f)

                fieldnames = [
                    "SCRSSN",
                    "DOB_MDR",
                    "Sex_MDR",
                    "UnderlyingCause_NDI",
                    "DOD_NDI",
                    "GBD_Cause1",
                    "GBD_Cause2",
                    "GBD_Cause3",
                    "GBD_Cause4",
                ]
                writer = csv.DictWriter(sys.stdout, fieldnames=fieldnames)
                writer.writeheader()
                for row in reader:
                    scrssn = row["SCRSSN"]
                    dob_mdr = row["DOB_MDR"]
                    sex_mdr = row["Sex_MDR"]
                    icd_code = row["UnderlyingCause_NDI"]
                    dod_ndi = row["DOD_NDI"]
                    if not icd_code:
                        causes = ["", "", "", ""]
                    else:
                        icd_version = determine_icd_version(icd_code)

                        cleaned_icd_code = clean_icd_code(icd_code, icd_version)

                        if icd_version == 9:
                            causes = map_to_causes(cleaned_icd_code, icd9_dict)
                        else:
                            causes = map_to_causes(cleaned_icd_code, icd10_dict)

                    writer.writerow(
                        {
                            "SCRSSN": scrssn,
                            "DOB_MDR": dob_mdr,
                            "Sex_MDR": sex_mdr,
                            "UnderlyingCause_NDI": icd_code,
                            "DOD_NDI": dod_ndi,
                            "GBD_Cause1": causes[0],
                            "GBD_Cause2": causes[1],
                            "GBD_Cause3": causes[2],
                            "GBD_Cause4": causes[3],
                        }
                    )

        except FileNotFoundError:
            print(f"Error: File not found: {filepath}")
        except Exception as e:
            print(f"An error occurred: {e}")
    else:
        print("Please provide a file path as a command-line argument.")


if __name__ == "__main__":
    main()
