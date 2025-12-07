# Cogitator

### One-liner
Proactive macOS co-pilot that sees your screen, OCRs it in ~0.5s, remembers your day with embeddings, and replies via XAI in ~3s—so you get help without asking.



https://github.com/user-attachments/assets/6b06956a-75c1-4ace-9fd3-b8eecd5f654c



### Why it matters
Manual prompting wastes time. Cogitator auto-collects context, anticipates needs, and keeps you focused on the actual task.

### Tech highlights
- OCR-first capture to turn visuals into text, slashing latency and compute vs. raw images.
- Embedding-backed day-long memory for semantic recall of what you saw or did earlier.
- Low-latency XAI pipeline tuned for sub-3s end-to-end responses.

### Architecture (thin slice)
- Capture: `ScreenRecorderService`, `OCRService` → fast text from screen frames.
- Memory: `EmbeddingService` → indexes daily activity for retrieval.
- LLM flow: `LLMPipelineService`, `XAIService` → prompt + generation with latency targets.
- UI: SwiftUI views (`DevCaptureView`, `ProductCaptureView`) orchestrated by `CogitatorApp` and `CaptureViewModel`.

### What’s next
Push accuracy and proactivity: richer context modeling, smarter retrieval, tighter latency budgets.
