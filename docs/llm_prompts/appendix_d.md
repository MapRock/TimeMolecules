Prompt: Should I use Azure Event Hubs or Apache Kafka as an event source for Time Molecules?

Abstract: Both Azure Event Hubs and Apache Kafka are high-throughput event streaming platforms suitable for feeding Time Molecules Markov-model pipelines. Event Hubs offers fully managed PaaS on Azure with automatic scaling, deep integration with Azure analytics services, and simple operational overhead. Kafka provides cloud-agnostic deployment, an extremely rich connector ecosystem, and fine-grained control over clusters. Both support ordered, partitioned streams keyed by case or entity ID and long retention for historical model rebuilding. The choice depends on existing infrastructure, preference for managed services, and need for cross-platform flexibility.

Primary Location (for more information): https://github.com/MapRock/TimeMolecules/blob/main/docs/Time_Molecules_Book_Eugene_Asahara_Appendices.md#appendix-d---azure-event-hub-vs-apache-kafka
