Prompt: How can I link cases?

Abstract: This tutorial explains how to infer links between separate case types in Time Molecules when the relationships are not explicitly modeled. It focuses on two related problems: detecting how different processes may connect through shared property values, and discovering whether cases involving different entities ever intersect. The approach combines semantic similarity of property names with matching of property values, so the system can identify plausible links such as an ER visit case and an MRI request case that share a common case identifier under differently named fields. It also shows how event-level proximity analysis can reveal intersections between case sets, including exact shared GPS coordinates, using sp_CompareEventProximities. Supporting assets include prompts and scripts for scoring semantic similarity between source columns, importing similar column pairs, and finding related case types.

This is one of the more advanced, but compelling use cases of Time Molecules.

The material for this tutorial is in: https://github.com/MapRock/TimeMolecules/tree/main/tutorials/link_cases
