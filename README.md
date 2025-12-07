# Cogitator

### At a glance
- macOS assistant that sees what you see, understands your context, and speaks up proactively.
- Focus on ultra-low-latency help: ~3s end-to-end replies, ~0.5s OCR, embedding-backed day-long memory.
- Built with macOS screen capture + OCR front-end, embedding history store, and XAI APIs for generation.

## Inspiration
Manually collecting context for LLMs is tedious and today’s assistants rarely help without constant prompting. Cogitator removes that overhead so you can stay focused on the work, not on orchestration.

## What it does
Cogitator runs locally on macOS as a close partner for daily work. It can “see” your screen, understand your activity, and respond with what you need—often without being asked—enabling a proactive AI workflow.

## How we built it
- macOS app with continuous screen capture and OCR to turn visuals into text quickly.
- Embedding-based history system to retain a full day of context for fast retrieval.
- XAI APIs for low-latency LLM responses; typical end-to-end latency is under 3 seconds.

## Challenges we ran into
High-performance inference alone wasn’t enough once users produced many recordings and images; raw image sends could take 10s+. Introducing OCR as a front-end step turned visuals into text, cutting both latency and compute cost.

## Accomplishments we’re proud of
- ~0.5s OCR latency for quick turns.
- Embedding-powered history that recalls related information from an entire day, making Cogitator feel like it “remembers” your work.

## What we learned
Long-term and high-salience memory remain key challenges. Balancing cost, speed, and smooth UX requires careful context storage and retrieval strategies across parallel workstreams.

## What’s next for Cogitator
Optimize across the stack: richer context modeling, smarter retrieval, more proactive behavior, and improved accuracy and robustness to make Cogitator feel even more natural day to day.

## Architecture overview
- **Capture**: `ScreenRecorderService` and `OCRService` capture the screen and convert images to text for lightweight downstream processing.
- **Memory**: Embedding pipeline (`EmbeddingService`) indexes activity across the day for semantic recall via a history store.
- **LLM Orchestration**: `LLMPipelineService` and `XAIService` handle prompt construction and generation with latency targets.
- **UX Layer**: SwiftUI views (`DevCaptureView`, `ProductCaptureView`) expose the experience on macOS with background services managed by `CogitatorApp` and `CaptureViewModel`.

## Quick pitch (concise version)
Cogitator is a proactive macOS assistant that watches your screen, OCRs it in ~0.5s, remembers your day with embeddings, and answers via XAI in ~3s—so you get help without having to ask.
