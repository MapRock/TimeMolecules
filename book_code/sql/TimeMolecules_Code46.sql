USE [TimeSolution]
GO
--[START Code 46]
DECLARE @ModelID INT = 1
SELECT
[CaseID], [AnomalyCode], [EventA], [EventB],
MetricAvg, MetricStDev, metric_value, metric_zscore,
[transistion_prob]
FROM
ModelEventAnomalies(@ModelID)
--[END Code 46]
