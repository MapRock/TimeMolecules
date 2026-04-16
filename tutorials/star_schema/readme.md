
Techniques on deriving conventional fact and dimension tables from the Event Ensemble, while keeping the main Time Molecules emphasis on Markov-model-driven change detection, drill-through, and conventional BI analysis of the underlying event and case properties. This really is about creating "silver medallion" star/snowflake schemas from the "bronze medallion" Event Ensemble.

Shows how the Event Ensemble, together with event-level and case-level properties, can be shaped into a conventional dimensional model.

Dimensional models were the usual form of Business Intelligence: fact tables for measurable business activity, and dimension tables for the descriptive context used to slice, dice, filter, and compare. In practice, the rows of many fact tables are events or event-derived transactions, even if they are not always described that way.

That said, this is not the primary point of Time Molecules. The main point is not merely to restate events as star schemas. The main point is to build Markov models from those events, identify where behavior changes, and then drill through to the underlying events and cases. Once those areas of difference are isolated, the event and case-level properties can be analyzed in a conventional BI manner through fact and dimension tables.

So the dimensional model here is a useful downstream analytic form of the Event Ensemble, not the central destination. The central destination is process-oriented understanding: detect meaningful differences in the Markov models first, then use conventional BI structures to study what properties help explain those differences.

The two example SQL are ad-hoc, but it shows the idea.

This is an extension of what I mention on page 126 of my book [Time Molecules](https://technicspub.com/time-molecules/): Open Schema Properties to an Outrigger Dimension Table
