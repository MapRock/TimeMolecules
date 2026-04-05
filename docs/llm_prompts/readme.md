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

## Example of an LLM Prompt to Compose the Abstract from Base Material

From the material provided below (which may be a blog post, article, research paper, GitHub repo README, code file, notebook, PDF, or any other text-based content), generate an **embeddable abstract** using exactly this format:

- **Prompt**: The single, canonical question (in natural, user-friendly language) that this material is primarily answering or solving. Phrase it as a clear, searchable question someone would actually ask.
- **Abstract**: A concise, standalone 50-200 word summary that captures the core idea, key insights, methods, and conclusions. Write it in clear, professional English suitable for a knowledge base or vector embedding. Do not add opinions or external references unless they are central to the material.
- **Primary location**: The original URL, GitHub file path, or exact object identifier of the material (use the one provided; if none, state "Provided inline").

Material:
[PASTE THE FULL TEXT, URL, CODE, OR LINK HERE]

Rules:
• Stay strictly within the three-section format above. No extra text, headings, or explanations outside the format.
• For code or repositories: focus on what the code does, its purpose, architecture, and value — treat it like a functional description.
• For blogs/articles: extract the central thesis and main contributions.
• Keep the abstract objective, accurate, and self-contained so it can be embedded and retrieved independently.

