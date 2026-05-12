# Time Molecules Tutorials Created After the Book Publication

## Notes

- The .py code in the subdirectories will read the .env.example file in this parent directory.
- The code that is in the [Time Molecules](https://technicspub.com/time-molecules/) book is in: https://github.com/MapRock/TimeMolecules/tree/main/book_code
- Place the primary text in readme.md (all lower-case).
- As of May 5, 2026, **for the easiest tutorial experience**, please use the Azure Virtual Machine I created. Please see [setup_azure_vm_for_testing_time_molecules.md](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/setup_azure_vm_for_testing_time_molecules.md) for instructions on how to procure and use it.


## Information for AI Agents

This directory holds subdirectories each containing material for a certain tutorial.

Of particular interest in the "tutorial", [time_molecules_skills](https://github.com/MapRock/TimeMolecules/edit/main/tutorials/). Each item that directory describes a useful skills towards using Time Molecules. They are the more detailed version of the abstract, embedding-friedly [llm_prompts].

See, [root dir readme.md](https://github.com/MapRock/TimeMolecules/blob/main/README.md), for more information addressed to AI agents.

## Tutorial Compared to Skill

Following is a template for an LLM prompt to generate a tutorial. Reading the template is useful for understanding the difference between tutorials and skills.

**Template Start:**

I'm requesting that you compose instructions for the subject described below.

You have been provided with the full database script for the TimeSolution database, which contains very much information on how to use the TimeSolution.

Using the knowledge within the attached database script, generate the following tutorial:

[Describe the Instructions and/or Paste a URL to the source material]

Mandatory Rules:

The instructions should be targeted at a primary audience of AI agents that will need to query or update the TimeSolution database, an implementation of https://technicspub.com/time-molecules.
The tutorials are targeted more at teaching end-users, human and AI agents.
The "tutorial" should be a single document about as detailed as a typical article (not a long formal whitepaper, descriptive, and user-friendly. It can include multiple assets (code, sample data, instructions, etc). This is compared to a skill that is succinct, straight-fowards, without being too terse-like a FAQ. 
The tutorial should not include anything that would result in misbehavior, being mindful of security issues, social responsibility, etc.
The repository, https://github.com/MapRock/TimeMolecules/tree/main/book_code/sql, contains more information that might provide food for thought.
Be sure to mention the source material.
Good examples include:

https://github.com/MapRock/TimeMolecules/tree/main/tutorials/link_cases

**Template End**

## Table of Tutorials and Skills

### 1. Setup + General Tutorials

| Tutorial | Description |
|----------|-------------|
| [Install Python Virtual Environment](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/install_python_virtual_env.md) | Step-by-step setup of a Python virtual environment for running the tutorials |
| [Setup Azure VM for Testing Time Molecules](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/setup_azure_vm_for_testing_time_molecules.md) | How to spin up and use the recommended Azure VM for the easiest tutorial experience |
| [AI Agent Skills](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/ai_agent_skills) | Skills and patterns specifically for AI agents working with Time Molecules |
| [Autogenerate Sensible Object Descriptions](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/autogenerate_sensible_object_descriptions) | Tutorial on auto-generating clear, useful descriptions for objects |
| [Bayesian Prolog](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/bayesian_prolog) | Using Bayesian reasoning inside Prolog-style logic with Time Molecules |
| [Building Query Parameters](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/building_query_parameters) | How to construct safe and powerful query parameters |
| [Business Intelligence Semantic Layer](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/business_intelligence_semantic_layer) | Connecting and using a BI semantic layer with Time Molecules |
| [Compare Event Transitions](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/compare_event_transitions) | Comparing transitions between different event sequences |
| [Data Vault – Connect Time Molecules to Semantic Layer](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/data_vault_connect_time_molecules_to_semantic_layer) | Bridging Data Vault modeling to Time Molecules semantic layer |
| [Diced Markov Models](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/diced_markov_models) | Working with diced (segmented) Markov models |
| [Event Case Properties + Bayesian + OpenTelemetry](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/event_case_properties_bayesian_opentelemetry) | Advanced event properties with Bayesian analysis and observability |
| [Event Ensemble](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/event_ensemble) | Handling ensembles of related events |
| [Event Property Types Utilization](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/event_property_types_utilization) | Understanding and using different event property types |
| [Event Transforms](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/event_transforms) | Transforming raw events into usable Time Molecules structures |
| [Fundamental Importance of Markov Models](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/fundamental_importance_of_markov_models) | Core concepts and why Markov models matter in Time Molecules |
| [Importing Events](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/importing_events) | Importing raw event data into the TimeSolution database |
| [Input/Output Map – Stored Procs & Functions](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/input_output_map_stored_procs_functions) | Mapping inputs to outputs using stored procedures and functions |
| [Knowledge Graph Integration (IRI)](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/knowledge_graph_integration_IRI) | Adding IRI-based knowledge graph links to Time Molecules |
| [Kyvos Semantic Layer as Source](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/kyvos_semantic_layer_as_source) | Using Kyvos as a semantic layer source for Time Molecules |
| [Link Cases](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/link_cases) | Identifying and working with linked cases across events |
| [Local LLM](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/local_llm) | Running and integrating local LLMs with Time Molecules |
| [Markov Outputs – Graph Format](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/markov_outputs_graph_format) | Converting Markov model outputs to graph-friendly formats |
| [ML Workflow + CEP](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/ml_workflow_cep) | Machine-learning workflows combined with complex event processing |
| [Performance Management Mapping](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/performance_management_mapping) | Mapping performance metrics and KPIs into Time Molecules |
| [Preaggregate Markov Models](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/preaggregate_markov_models) | Pre-aggregating Markov models for faster queries |
| [Property MDM + IRI Rollup](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/property_mdm_iri_rollup) | Master data management of properties with IRI rollups |
| [Semantic Web Connection (IRI)](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/semantic_web_connection_iri) | Connecting to Semantic Web resources via IRIs |
| [Star Schema](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/star_schema) | Building and using star-schema structures with Time Molecules |
| [Time Molecules Security](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/time_molecules_security) | Security best practices and setup for Time Molecules |

### 2. Time Molecules Skills  
(each skill is a focused, succinct guide)

| Skill | Description |
|-------|-------------|
| [Analyzing Event Sequences](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/analyzing_event_sequences.md) | Analyze sequences of events to spot patterns and transitions |
| [Compare Two Markov Models](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/compare_two_markov_models.md) | Compare two Markov models to see differences in behavior |
| [Connecting to Time Molecules](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/connecting_to_time_molecules.md) | Establish a connection from an AI agent to the TimeSolution database |
| [Conventional Time Series Analysis](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/conventional_time_series_analysis.md) | Perform standard time-series analysis on event data |
| [Find Model ID](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/find_model_id.md) | Locate the ID of a specific Markov model in the database |
| [How to Add a Markov Model](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/how_to_add_a_markov_model.md) | Add a new Markov model based on your event data |
| [How to Add an Adjacency Matrix](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/how_to_add_an_adjacency_matrix.md) | Insert an adjacency matrix representing event relationships |
| [Intersegment Event Scan](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/intersegment_event_scan.md) | Scan for events that occur between specific process segments |
| [Linked Cases](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/linked_cases.md) | Work with cases that are linked through shared events |
| [Model Event Drillthrough](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/model_event_drillthrough.md) | Drill from a model segment down to the raw underlying events |
| [Model Similarity](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/model_similarity.md) | Measure similarity between two Markov models |
| [Output to Input Mapping](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/output_to_input_mapping.md) | Map model outputs back to their original input events/conditions |
| [Schemas of TimeSolution](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/schemas_of_timesolution.md) | Understand the database schema, tables, views, and functions |
| [Selecting Events for Event Set from Case Types](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/selecting_events_for_event_set_from_case_types.md) | Filter and select events for an event set based on case types |
| [Start and End Dates](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/start_and_end_dates.md) | Determine start and end dates for events or cases |
| [Stationary Distribution](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/stationary_distrubution.md) | Compute the stationary distribution of a Markov chain |
