# Collection of Documents addressing common prompts for Time Molecules.

Each document in this directory will be LLM-embedded in full for the purpose of fuzzy searching. It will be imported into a vector database, a repository of material related to [Time Molecules](https://technicspub.com/time-molecules/).

Each document should be on the short side, just an abstract, geared towards a question. There are these main parts:

- **Prompt**: The cannonical question that is answered.
- **Abstract**: A 50-200 word summary.
- **Primary location**: The URL or object from which this abstract was made.

There is no strict format. This is meant for embedding, so the most important thing is to write text conducive to matching the prompt.

## Notes

- Only provide links in the https://github.com/MapRock/ and eugeneasahara.com domains. I want to remove risk of linking to bad sites.

## Example of a Document

Prompt: How can I create a Markov Model?

Abstract: Creating a Markov Model involves specifying parameters of the model and extracting events that meet those requirements. Those events are them compressed by event into the Markov model.

Primary Location (for more information): The stored prodecure, MarkovProcess2, is the primary object to call.

I generally use openai for this task. It does a better job than the small local AIs. This works well for these public materials, but would be an issue if the material is proprietary.

## Template for the LLM Prompt to Compose the Abstract from Base Material  (the entire topic is the prompt)

From the material provided below (which may be a blog post, article, research paper, GitHub repo README, code file, notebook, PDF, or any other text-based content), generate an embeddable abstract using exactly this format:

- Prompt: The single, canonical question (in natural, user-friendly language) that this material is primarily answering or solving. Phrase it as a clear, searchable question someone would actually ask. The phrasing should be how a user will ask about a concept-they probably wouldn't ask about implementation code.
- Abstract: A concise, standalone 50-200 word explanation of the core concept or idea itself. Write it as if you are directly explaining the main thesis or invention to someone who has never seen the material. Do not describe the blog post, article, or author. Do not use phrases like “The post presents…”, “This article introduces…”, “The author shows…”, “The preview discusses…”, or any meta-reference to the document. Treat the material as the direct source of the idea and explain the idea itself in clear, professional, self-contained English suitable for a knowledge base or vector embedding. 
- Primary location of source material to analyze (for more information): [insert URL]

Rules:

- The prompt element should be phrased as a user or AI agent might question. Usually, they know what they want to do but won't know the implementation details.
- Stay strictly within the three-section format above. No extra text, headings, or explanations outside the format. Be sure to include all three sections.
- For blogs/articles: extract the central thesis and main contributions, then express them directly as factual explanation of the concept. Keep the focus on what the selected material is about.
- When the material is a code file, SQL script, notebook, or any implementation artifact, the Prompt and Abstract MUST focus exclusively on what this specific file/script actually contains and implements. Do not generalize to the broader technique, concept, or framework it belongs to.
- For code files: the Prompt must explicitly reference the concrete SQL objects (functions, procedures, views, tables, etc.), logic, or code structures defined in the material. Example: “What specific SQL code, table-valued functions, views, and procedures does the TimeMolecules_Code42.sql script provide…”
- Keep the Abstract concrete and implementation-specific: describe the exact objects created, their inputs/outputs, how they interact, and what they enable inside this particular script/file. Never expand into high-level overviews of the overall idea.
- Keep the abstract objective, accurate, and self-contained so it can be embedded and retrieved independently.
- This is not about summarizing what the resource says about itself. It is about distilling and directly presenting the main idea the material is communicating.
- Include key words in the prompt and abstract for the URL that you think is beneficial for embedding searches.


## The Process for Creating the Vector Database

- **EXEC dbo.BuildTimeSolutionsMetadata**: Run this stored procedure to update metadata in TimeSolutuion. This is the primary material for the vector database.
- **Create llm_prompt items**: Use the template shown above to present instructions to an LLM to create any number of items to be added into the vector database.
- **[qdrant_demo_ollama.py](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/local_llm/qdrant_demo_ollama.py)**: Imports items into a vector database.
- **[qdrant_demo_UI_ollama.py](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/local_llm/qdrant_demo_UI_ollama.py)**: UI for ollama that uses the vector database.



