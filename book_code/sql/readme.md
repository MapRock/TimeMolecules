TimeMolecules_Code04.sql through TimeMolecules_Code75.sql reflect SQL code in the book, Time Molecules. Each is:

1. Run from the TimeSolution database (restored from TimeSolution.bak). My intent is to use SQL Server Management Studio (SSMS) as the "query tool" for these SQL snippets.
2. Idempotent--meaning they can be run multiple times with no adverse side-effect to the TimeSolution database.

The gaps in numbering (ex. TimeMolecules_Code01.sql isn't in this folder because it doesn't fit the criteria I just listed.

In the future, this folder will house additional code reflecting further examples. They will be named outside of the TimeMolecules_CodeXX.sql pattern. 

<b>Important Notes:</B>
<ul>
  <li>
In the book, I say that all the SQL code is consolidated into the file, time_molecules_code_from_book.sql. But I later decided to separate each code in order to avoid having to redefine variables so that code could be highlighted and run. Instead, each code is in its own file and users an open the file and simply Execute.
    </li>
  <li>
Code 72 in the book has a typo. In the SELECT, it refers to [CaseType], which should be [GroupType]. That change is reflected in the code in this directory (TimeMolecules_Code72.sql).
    </li>
</ul>
