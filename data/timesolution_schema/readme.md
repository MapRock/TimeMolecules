Generated using SQL Server's "generate scripts" function.

Each stored procedure, table-valued function, and scalar function, contain extensive metadata (comments at the top of the script).

Created in three parts (stored procedures, tables, and views/TVF) to avoid one big file.

- https://github.com/MapRock/TimeMolecules/blob/main/data/timesolution_schema/timesolution_stored_procedures.sql - DDL of the Time Molecules stored procedures.
- https://github.com/MapRock/TimeMolecules/blob/main/data/timesolution_schema/tables.sql - DDL of the Time Molecules tables and columns.
- https://github.com/MapRock/TimeMolecules/blob/main/data/timesolution_schema/timesolution_views.sql - DDL of the Time Molecules views, table-valued functions, and scalar functions.

Other Files:
- https://github.com/MapRock/TimeMolecules/blob/main/data/timesolution_schema/TimeMolecules_Metadata.csv - Exported data from the vwTimeSolutionMetadata view. This is so you don't need to install TimeSolution to play with the [ai_agent_skills](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/ai_agent_skills) tutorial.
- https://github.com/MapRock/TimeMolecules/blob/main/data/timesolution_schema/timesolution_output_to_input_edges.csv - See https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/output_to_input_mapping.md for an explanation of this file.

