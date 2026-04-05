# Collection of Documents addressing common prompts for Time Molecules.

Each document in this directory will be embedded in full for the purpose of fuzzy searching.

Each document should be on the short side, just an abstract, geared towards a question. There are these main parts:

- **Prompt**: The cannonical question that is answered.
- **Abstract**: A 50-200 word summary.
- **Primary location**: The URL or object of more information.

There is no strict format. This is meant for embedding, so the most important thing is to write text conducive to matching the prompt.

## Example of a Document

Prompt: How can I create a Markov Model?

Abstract: Creating a Markov Model involves specifying parameters of the model and extracting events that meet those requirements. Those events are them compressed by event into the Markov model.

Primary Location: The stored prodecure, MarkovProcess2, is the primary object to call.

## Example of an LLM Prompt to Compose the Abstract from Base Material  (the entire topic is the prompt)

From the material provided below (which may be a blog post, article, research paper, GitHub repo README, code file, notebook, PDF, or any other text-based content), generate an embeddable abstract using exactly this format:

Prompt: The single, canonical question (in natural, user-friendly language) that this material is primarily answering or solving. Phrase it as a clear, searchable question someone would actually ask.
Abstract: A concise, standalone 50-200 word explanation of the core concept or idea itself. Write it as if you are directly explaining the main thesis or invention to someone who has never seen the material. Do not describe the blog post, article, or author. Do not use phrases like “The post presents…”, “This article introduces…”, “The author shows…”, “The preview discusses…”, or any meta-reference to the document. Treat the material as the direct source of the idea and explain the idea itself in clear, professional, self-contained English suitable for a knowledge base or vector embedding.
Primary location of source material to analyze: [PASTE THE FULL TEXT, URL, CODE, OR LINK HERE]

Rules:

Stay strictly within the three-section format above. No extra text, headings, or explanations outside the format.
For blogs/articles: extract the central thesis and main contributions, then express them directly as factual explanation of the concept.
Keep the abstract objective, accurate, and self-contained so it can be embedded and retrieved independently.
This is not about summarizing what the resource says about itself. It is about distilling and directly presenting the main idea the material is communicating.


## The Process

- **EXEC dbo.BuildTimeSolutionsMetadata**: Run this stored procedure to update metadata in TimeSolutuion. This is the primary material for the vector database.
- **[qdrant_demo_ollama.py](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/local_llm/qdrant_demo_ollama.py)**: Imports items into a vector database.
- **[qdrant_demo_UI_ollama.py](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/local_llm/qdrant_demo_UI_ollama.py)**: UI for ollama that uses the vector database.



