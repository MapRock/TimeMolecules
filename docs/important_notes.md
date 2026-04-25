
# Important Transitory Notes

Notes about subjects that are prone to rapid change.

## Frontier Model Intermittently will not Read URLs in the Prompt 

Date Created: 4/24/2026
Last Update: 4/25/2026

ChatGPT occasionally refuses to read links in the prompt. When ChatGPT feels like reading links, the responses are helpful, but not as much as it is with Grok. Gemini responds in the least helpful way. That inconsistency is the reason the time_molecules_agent_demo app for exploring the functionality and utilization of Time Molecules.


ChatGPT does not have built-in, always-on internet access. It can only read a link if the "Browsing" feature (powered by Bing) is turned on in that chat — and even then, it's flaky.
Main reasons it fails:

Browsing isn't enabled → The model literally cannot open the link and will either say "I can't access that" or just make something up.
The browsing tool is unreliable → It often times out, gets blocked by the site, or returns a terrible/partial summary (especially with raw GitHub links, code files, or long pages).
The model is lazy → Sometimes it simply ignores the link and answers from memory instead of actually triggering the browse tool.

If the content is important, just copy-paste the actual text (or the full file contents) directly into your prompt. That way ChatGPT is guaranteed to see it.
