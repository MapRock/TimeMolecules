# Tutorial: Discovering Hidden States in Texas Hold’em Poker Using Time Molecules, Video-Enriched Events, CEP, and Azure ML

This is a **complete, hands-on tutorial** that walks through **exactly** how to automate the discovery of hidden states in a real-world process — this time using the **Texas Hold’em poker** example from *Time Molecules* (pages 94, 101, 143–145, and Appendix H).  

We’ll add the new dimension you asked about: **live or recorded video feeds** (table cams, live streams, or security footage) that Azure AI can analyze for **verbal tells** (speech patterns, timing, tone) and **body-language tells** (facial micro-expressions, posture, fidgeting, eye contact). This turns sparse poker logs into a massively rich event fabric — exactly the “tens of thousands of features” scenario you described.

The entire pipeline is production-ready today in Azure and maps 1:1 to the Time Molecules concepts of:
- Atomic events + rich payloads
- Transforms & synthetic events
- Markov/HMM ensembles for sequence modeling
- Bayesian/conditional layering for context

You can copy-paste this tutorial straight into a notebook, share it with your team, or use it as the basis for a quick proof-of-concept. I’ve included **exact Azure service names**, **MLflow integration**, and **step-by-step pipeline diagrams** so your Data Engineering / Data Science team can implement it immediately.

## 1. Poker in Time Molecules – The Foundation
In the book we treat each player **action** as an atomic event:
- `event.name`: "bet", "check", "raise", "fold", "call", "all_in", etc.
- Payloads include stack size, position, pot odds, board cards, prior action sequence, etc.

Hidden states (the “intuition” part) include:
- Player aggression/bluff frequency
- Fatigue (after 8+ hours)
- Table dynamics
- **Tells** (now auto-detected from video!)

Video enrichment closes the domain-knowledge gap: a player’s “steady gaze + calm voice” vs. “nervous fidget + higher-pitched speech” becomes machine-readable attributes that feed clustering, association rules, and HMMs.

### 2. Sample Enriched Event (JSON) – With Video-Derived Tells
Here’s a realistic poker event after CEP + Azure AI processing:

```json
{
  "time_unix_nano": 1717359286123456789,
  "body": { "event.name": "raise" },
  "attributes": {
    "case.game_id": "poker_game_042",
    "case.hand_id": "hand_017",
    "case.player_id": "player_hero_03",
    "event.action_number_in_hand": 4,
    "event.bet_amount": 450,
    "actual.position": "button",
    "actual.stack_size": 12450,
    "actual.board": ["Ah", "Ks", "7d", "2c"],
    "context.pot_size": 2100,
    "context.opponents_remaining": 3,
    "context.phase": "flop",
    "video.tell.facial_emotion": "fear",                  // from Azure AI Vision / Video Indexer
    "video.tell.body_language": "nervous_fidget",         // custom model on posture + hand movement
    "video.tell.speech_pattern": "higher_pitch",          // from Speech + tone analysis
    "video.tell.timing": "instant_bet",                   // reaction time < 1.2s
    "hidden.player_aggression": 0.82,                     // inferred from sequence + tells
    "hidden.bluff_likelihood": 0.67,
    "hidden.fatigue_level": "elevated",
    "expected.outcome.fold_probability": 0.41,
    "expected.outcome.call_probability": 0.33
  }
}
```

These video attributes are **automatically extracted** in real time — no manual labeling required.

### 3. End-to-End Azure Pipeline (CEP + Azure ML + Video Enrichment)

**High-level flow** (real-time + batch):
1. Raw events (poker tracking software) + video streams → **Azure Event Hubs**
2. **Azure Stream Analytics** (CEP) + Azure AI services → enrich with video tells
3. Enriched events land in **Azure Data Lake** (Delta tables)
4. **Azure Machine Learning** pipelines (MLflow-tracked) → discover hidden states
5. Models/rules deployed back into Stream Analytics for live scoring
6. Inferred hidden states become new event attributes → feed Time Molecules Markov/HMM + Bayesian layer

#### Detailed Azure ML Workflow (Step-by-Step for Poker + Video)

1. **Ingestion & Real-Time Video Enrichment (CEP Layer)**  
   - Poker events + live table video streams into Event Hubs.  
   - **Azure Stream Analytics** job:  
     - Windowed queries on action sequences.  
     - Calls **Azure AI Video Indexer** (or Azure Computer Vision + Face API) on video frames:  
       - Face detection + emotion (joy/fear/sadness/anger/neutral)  
       - Observed people + posture proxies  
       - Speech-to-text + tone/pitch analysis (via Azure AI Speech)  
       - Timing tells (reaction time between card reveal and action)  
     - For advanced body-language tells, extract frames with FFmpeg (in Azure Functions) and run a **custom Azure ML model** trained on labeled poker footage.  
   - Output: enriched Parquet/Delta events with the `video.tell.*` attributes above.

2. **Azure ML Pipeline (MLflow-native, versioned)** – Built in Azure ML Studio or Python SDK  
   - **Step 1: Data ingestion** – Read enriched Delta tables (filtered by game/hand/player).  
   - **Step 2: Feature engineering** (your “tens of thousands of features”):  
     - Sequence features (last N actions + tells)  
     - Aggregates (hours played → fatigue proxy)  
     - Video-derived features (emotion frequency, fidget count per hour)  
     - Time Molecules transforms (e.g., group “raise + instant timing + fear emotion” into synthetic “bluff_attempt” event)  
   - **Step 3: Hidden-state discovery** (MLflow autologs everything):  
     - Dimensionality reduction: PCA / autoencoders → keep the 100–300 features that actually drive outcomes.  
     - Unsupervised clustering (K-means / DBSCAN): Groups hands into unlabeled “bluff patterns” or “value-betting tells.”  
     - Association rules (FP-Growth): “If fear_emotion + instant_raise on dry board → 74% bluff.”  
     - Supervised models: XGBoost / Random Forest → predict fold/call probability; feature importance surfaces which tells matter most.  
     - Sequence models: HMM (or LSTM via PyTorch) using Time Molecules transforms → learns hidden states (aggression, fatigue) over entire sessions.  
     - Bayesian layer: Conditional probabilities incorporating table context + video tells (exactly as in Chapter 9, pages 205, 220, 282).  
   - **Step 4: Evaluation & drift** – MLflow tracks metrics; Azure ML data-drift monitors retrain when new player styles or camera angles appear.  
   - **Step 5: Model registration** – Versioned in Azure ML registry (native MLflow format).

3. **Deployment & Closed Loop**  
   - Deploy as real-time endpoint **or** compile to ONNX/PMML and push into Stream Analytics (as UDF).  
   - Inferred hidden states (`hidden.bluff_likelihood`, `hidden.fatigue_level`) are written back as new attributes.  
   - These flow into your next Markov model run → continuous learning.  
   - Full MLOps: GitHub Actions + Azure ML pipelines = repeatable, auditable strategy detectors.

**Total time to working prototype on public poker datasets (or your own logs):** 1–2 weeks.

### 4. ML Techniques That Directly Answer “How Do You Discover Hidden States?”
| Technique                  | Poker Example Output                                      | How It Helps Hidden States          |
|----------------------------|-----------------------------------------------------------|-------------------------------------|
| Clustering                 | Groups of “nervous raise” patterns                        | Auto-discovers strategy clusters   |
| Association Rules          | “fear + instant timing → bluff”                           | Interpretable rules                |
| Decision Trees / XGBoost   | Feature importance ranks “fidget_count” highest           | Explains which tells matter        |
| HMM / LSTM                 | Learns transition probabilities between hidden states     | Core Time Molecules modeling       |
| Bayesian Conditioning      | “Given fear emotion + dry board + 3 opponents…”           | Hybrid Markov + conditional layer  |

### 5. Serializing Rules (Prolog or ML Models)
- **Prolog route** (recommended for auditability): Use the “Prolog in the LLM Era” series to convert decision trees / association rules into executable Prolog facts/predicates.
  - Part 1 – Soft Coded Logic https://eugeneasahara.com/2024/08/04/does-prolog-have-a-place-in-the-llm-era/ → Shows MetaRules that automatically turn ML decision trees / association rules into executable Prolog predicates.
  - Conditional Trade-Off Graphs https://eugeneasahara.com/2025/11/17/trade-off-semantic-network-prolog-in-the-llm-era-ai-3rd-anniversary-special/ → Perfect for encoding conditional poker strategies and “it depends” logic with exceptions and guard conditions. 

### 6. Key References 
- **Reptile Intelligence: An AI Summer for CEP** → https://eugeneasahara.com/2025/09/25/reptile-intelligence-an-ai-summer-for-cep/  
- **Thousands of Senses** → https://eugeneasahara.com/2025/06/15/thousands-of-senses/  
- **Prolog in the LLM Era** series → https://eugeneasahara.com/2024/08/04/does-prolog-have-a-place-in-the-llm-era/ (and the two follow-ups)  
- GitHub repo prompts: `[event_transforms.md](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/event_transforms)`, `[analyzing_event_sequences.md](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/analyzing_event_sequences.md)`

