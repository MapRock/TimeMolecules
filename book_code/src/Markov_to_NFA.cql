/*
Author: ChatGPT and Eugene Asahara

Description:

This is related to Code 79, Figure 96, and Figure 97 in the book "Time Molecules".
It is a Cypher script created from the prompt (Code 79) to convert a Markov chain into a Non-deterministic Finite Automaton (NFA) model:

Please study the attached Markov model that is based on events serving customers in a
restaurant. Please create an NFA based on the events shown in the Markov model. The nodes
of the Markov model become the edges of the NFA. You must Infer the state that the NFA
nodes represent from the nodes of the Markov model. Create Neo4j Cypher for creating that
NFA.


 
===========================================================================================
⚙️  HOW TO LOAD AND VISUALIZE THIS NFA MODEL IN NEO4J BROWSER
===========================================================================================

1. OPEN NEO4J BROWSER
   - Launch Neo4j Desktop.
   - Start your database instance.
   - Click "Open" to launch Neo4j Browser (typically opens at http://localhost:7474).
   - Log in with your database credentials (default user: neo4j).

2. COPY AND PASTE THIS CODE
   - In VS Code, select all Cypher statements in this file.
   - Paste them into the Neo4j Browser query input bar.
   - Press Shift+Enter to execute.

3. CONFIGURE THE GRAPH VIEW FOR READABILITY

   a. Display node labels:
      - After running the script, click on any node.
      - Click the style paintbrush icon (⚙️ → "Node" → "Caption").
      - Set Caption to `label` to show the state names.

   b. Display relationship labels:
      - Click the style paintbrush icon (⚙️ → "Relationship" → "Caption").
      - Set Caption to `event` to show transition names (e.g., order, depart).

   These settings will persist for your current session.

4. EXPLORE THE GRAPH
   - Use the Neo4j Browser's drag-and-zoom interface to explore transitions.
   - You can run queries like:
       MATCH (a:State)-[r]->(b) RETURN a, r, b

===========================================================================================
*/

// Step 1: Create States
UNWIND [
  ['S0', 'Pre-Arrival'],
  ['S1', 'Arrived'],
  ['S2', 'Seated'],
  ['S3', 'Intro'],
  ['S4', 'Ordered'],
  ['S5', 'Drinks'],
  ['S6', 'Served'],
  ['S7', 'Check'],
  ['S8', 'Charged'],
  ['S9', 'Payment Declined'],
  ['S10', 'Charged Again'],
  ['S11', 'Big Tip'],
  ['S12', 'Departed']
] AS pair
MERGE (:State {id: pair[0], label: pair[1]});

// Step 2: Create Transitions
UNWIND [
  ['arrive', 'S0', 'S1'],
  ['greeted', 'S1', 'S2'],
  ['intro', 'S2', 'S3'],
  ['order', 'S3', 'S4'],
  ['drinks', 'S4', 'S5'],
  ['order', 'S5', 'S4'], // Optional loop back
  ['served', 'S4', 'S6'],
  ['check', 'S6', 'S7'],
  ['charged', 'S7', 'S8'],
  ['bigtip', 'S8', 'S11'],
  ['depart', 'S11', 'S12'],
  ['depart', 'S8', 'S12'],
  ['ccdecline', 'S7', 'S9'],
  ['charged1', 'S9', 'S10'],
  ['depart', 'S10', 'S12'],
  ['depart', 'S0', 'S12'],
  ['depart', 'S1', 'S12'],
  ['depart', 'S2', 'S12']
] AS transition
MATCH (from:State {id: transition[1]}), (to:State {id: transition[2]})
MERGE (from)-[r:TRANSITION {event: transition[0]}]->(to);
