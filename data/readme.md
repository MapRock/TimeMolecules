# TimeSolution.bak - Official SQL Server Sample Database for Time Molecules

This `.bak` file is the official backup used for tutorials and examples in the book  
**<i>[Time Molecules](https://technicspub.com/time-molecules/)</i> by Eugene Asahara** (Technics Publications, 2025).

---

### See /docs/install_timemolecules_dev_env.pdf for instructions on setting up the sample SQL Server database, TimeSolution.bak.

### Included Files (download into c:/MapRock/TimeMolecules/data)

- <b>`TimeSolution.bak`</b> — SQL Server backup file. Download from onedrive storage: https://1drv.ms/u/c/7d94c9ab48b30303/EWpwyb0Z2-9AnOOBMK7ahXUBaskdgzsUUDLE_B3zvOuLeQ?e=LisfIo
- `TimeSolution.bak.asc` — Digital signature file (signed by Eugene Asahara)
- `publickey.asc` — Public key to verify the signature
- `LicenseAndDisclaimer.txt` — Legal and usage notes

## Updates

The TimeSolution.bak database was updated on March 31, 2026. It could be considered a "dot-one" cleanup:

- Modified the SQL Server code (stored procedures and table-valued functions) to be more easily portable to higher-scale platforms. It should be mostly portable to Azure Managed Instances (which is essentially SQL Server in the Cloud).
- Modified TVF to be 'inline'.
- Expanded some NVARCHAR columns meant to act as "codes" from 20 chars to 50.

