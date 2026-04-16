# Time Molecules Tutorials Created After the Book Publication

## Notes

- The .py code in the subdirectories will read the .env.example file in this parent directory.
- The code that is in the [Time Molecules](https://technicspub.com/time-molecules/) book is in: https://github.com/MapRock/TimeMolecules/tree/main/book_code
- Place the primary text in readme.md (all lower-case).

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
