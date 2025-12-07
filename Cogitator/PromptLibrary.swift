//
//  PromptLibrary.swift
//  Cogitator
//

import Foundation

struct PromptLibrary {
    static let sanityCheck = "Reply with the word 'ACK' if you received this message."

    static func ingestionSummaryPrompt(from log: String) -> String {
        """
        You are an assistant that reviews chronological OCR logs taken from a macOS desktop. Your job is to produce a concise summary of what the user was doing and highlight any actionable insights. Limit the response to a short paragraph and, if relevant, a bullet list of next steps. Use the provided timestamps to keep context, but do not repeat every line verbatim.

        OCR Log:
        \(log)
        """
    }
    
    static func predictorPrompt(from log: String) -> String{
        """
        You are an writer assitant that help user write something, based on the context provided is screen record ocr , you need understand what user is doing, and this user is ready to write something based on this context, you should know what is user want to write based on the screen record ocr, and return back the content that user want to write. No need to explain , no analysis, just the content that user want to write. which user can copy and paste directly.
        
        OCRLog:
        \(log)
        """
    }
}
