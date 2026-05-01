Prompt: How does the one-pass weighted standard deviation algorithm work in Time Molecules?

Abstract: The one-pass weighted incremental algorithm (West’s variant of Welford’s method) computes running variance and standard deviation in a single pass over the data stream. It maintains three running totals — total weight, running mean, and accumulated squared error — updating them in constant time and constant space for every new observation. This approach eliminates the expensive second pass required by the classic two-pass method, making it ideal for large-scale, distributed, and streaming environments in Time Molecules.

Primary Location (for more information): https://github.com/MapRock/TimeMolecules/blob/main/docs/Time_Molecules_Book_Eugene_Asahara_Appendices.md#appendix-j---weighted-standard-deviation
