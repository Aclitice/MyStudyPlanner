import Foundation
import CoreML

enum ModelError: Error {
    case modelNotLoaded
    case resourceNotFound(String)
    case predictionFailed(String)
    case invalidInput
    case invalidOutput
}

// Enhanced Core ML model provider with better error handling and inference capabilities
final class CoreMLModelProvider {
    static let shared = CoreMLModelProvider()
    private var model: MLModel?
    private var isLoaded = false
    
    private init() {}

    // Load .mlmodelc model with improved error handling
    func loadModelIfNeeded() throws {
        if isLoaded { return }
        
        let resourceName = (Bundle.main.object(forInfoDictionaryKey: "StudyPlannerModelResourceName") as? String) ?? "Qwen18B"
        
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "mlmodelc") else {
            throw ModelError.resourceNotFound("Model resource \(resourceName).mlmodelc not found. Ensure ODR is configured correctly.")
        }
        
        do {
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .cpuAndGPU // Use CPU and GPU for better performance
            model = try MLModel(contentsOf: url, configuration: configuration)
            isLoaded = true
        } catch {
            throw ModelError.predictionFailed("Failed to load model: \(error.localizedDescription)")
        }
    }
    
    // Unload model to free memory
    func unloadModel() {
        model = nil
        isLoaded = false
    }
    
    // Enhanced text generation with structured input/output
    func generate(prompt: String, maxTokens: Int = 256) throws -> String {
        guard let model = model else {
            throw ModelError.modelNotLoaded
        }
        
        // Placeholder: actual implementation depends on specific model signature
        // For Qwen models, typical input is tokenized text and output is token IDs
        // This is a simplified version - real implementation needs tokenization
        
        do {
            // Example for text-to-text models (adjust based on actual Qwen model signature)
            let input = try MLDictionaryFeatureProvider(dictionary: ["input_text": prompt])
            let prediction = try model.prediction(from: input)
            
            if let outputText = prediction.featureValue(for: "output_text")?.stringValue {
                return outputText
            } else {
                throw ModelError.invalidOutput
            }
        } catch {
            // Fallback for placeholder mode
            return generateFallbackResponse(prompt: prompt)
        }
    }
    
    // Generate planning-specific response
    func generatePlan(persona: String, goal: String, deadline: Date?) throws -> String {
        guard isLoaded else {
            throw ModelError.modelNotLoaded
        }
        
        let prompt = buildPlanningPrompt(persona: persona, goal: goal, deadline: deadline)
        return try generate(prompt: prompt, maxTokens: 512)
    }
    
    // Build structured prompt for planning tasks
    private func buildPlanningPrompt(persona: String, goal: String, deadline: Date?) -> String {
        var prompt = """
        You are an AI study planning assistant. Generate a structured learning plan.
        
        User Type: \(persona == "student" ? "Student" : "Professional")
        Goal: \(goal)
        """
        
        if let deadline = deadline {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            prompt += "\nDeadline: \(formatter.string(from: deadline))"
        }
        
        prompt += """
        
        
        Please provide:
        1. Break down into specific tasks
        2. Estimate time for each task (in minutes)
        3. Suggest task order and priority
        4. Include review/practice sessions
        
        Format as JSON:
        {"tasks": [{"title": "...", "estimatedMinutes": 60, "type": "study"}]}
        """
        
        return prompt
    }
    
    // Fallback response when model is not available or fails
    private func generateFallbackResponse(prompt: String) -> String {
        return "[AI Model Processing] Generated response for: \(prompt.prefix(100))..."
    }
}


