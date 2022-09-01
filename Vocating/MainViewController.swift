//
//  MainViewController.swift
//  Vocating
//
//  Created by Hong jeongmin on 2022/09/01.
//

import UIKit
import Speech
import SoundAnalysis

class MainViewController: UIViewController, SFSpeechRecognizerDelegate {
    
    //MARK: - Properties
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))!
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let audioEngine = AVAudioEngine()
    
    let model = try! Emotion()
    var analyzer: SNAudioStreamAnalyzer!
    let analysisQueue = DispatchQueue(label: "com.custom.AnalysisQueue")
    var resultsObserver = ResultsObserver()
    
    private let emotionText: UILabel = {
        let label = UILabel()
        label.text = "감정상태가 이곳에 표시됩니다."
        
        return label
    }()
    
    private let audioButton: UIButton = {
        let button = UIButton()
        button.setTitle("당신의 음성을 들려주세요!", for: .normal)
        button.addTarget(self, action: #selector(audioAction), for: .touchUpInside)
        button.backgroundColor = .blue
        
        return button
    }()
    
    private let audioText: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = .gray
        textView.text = "아래 버튼을 눌러 당신의 음성을 들려주세요!"
        
        return textView
    }()
    
    //MARK: - LifeCycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        resultsObserver.delegate = self
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        speechRecognizer.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.audioButton.isEnabled = true
                    
                case .denied:
                    self.audioButton.isEnabled = false
                    self.audioButton.setTitle("마이크 사용 권한을 허용해주세요.", for: .disabled)
                    
                case .restricted:
                    self.audioButton.isEnabled = false
                    self.audioButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                    
                case .notDetermined:
                    self.audioButton.isEnabled = false
                    self.audioButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                    
                default:
                    self.audioButton.isEnabled = false
                }
            }
        }
    }
    
    private func startRecording() throws {
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode
        analyzer = SNAudioStreamAnalyzer(format: inputNode.inputFormat(forBus: 0))
        
        do {
            let request = try SNClassifySoundRequest(mlModel: model.model)
            try analyzer.add(request, withObserver: resultsObserver)
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = true
        
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        
        // Create a recognition task for the speech recognition session.
        // Keep a reference to the task so that it can be canceled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                // Update the text view with the results.
                self.audioText.text = result.bestTranscription.formattedString
                isFinal = result.isFinal
                print("Text \(result.bestTranscription.formattedString)")
            }
            
            if error != nil || isFinal {
                // Stop recognizing speech if there is a problem.
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.audioButton.isEnabled = true
                self.audioButton.setTitle("당신의 음성을 들려주세요!", for: [])
                self.audioText.text = "아래 버튼을 눌러 당신의 음성을 들려주세요!"
                self.emotionText.text = "감정상태가 이곳에 표시됩니다."
            }
        }
        
        // Configure the microphone input.
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
            self.analyzer.analyze(buffer, atAudioFramePosition: when.sampleTime)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // Let the user know to start talking.
        audioText.text = "당신의 음성이 이곳에 표시됩니다."
    }
    
    //MARK: - Selectors
    
    @objc func audioAction(sender: UIButton!) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            audioButton.isEnabled = false
            audioButton.setTitle("마이크 끄는중...", for: .disabled)
        } else {
            do {
                try startRecording()
                audioButton.setTitle("말하기 중단!", for: [])
            } catch {
                audioButton.setTitle("마이크 사용 불가", for: [])
            }
        }
    }
    
    //MARK: - Helpers
    
    func configureUI() {
        //레이아웃 구성
        self.view?.addSubview(emotionText)
        emotionText.translatesAutoresizingMaskIntoConstraints = false
        emotionText.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 100).isActive = true
        emotionText.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        
        self.view?.addSubview(audioButton)
        audioButton.translatesAutoresizingMaskIntoConstraints = false
        audioButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        audioButton.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -50).isActive = true
        
        self.view.addSubview(audioText)
        audioText.translatesAutoresizingMaskIntoConstraints = false
        audioText.bottomAnchor.constraint(equalTo: self.audioButton.topAnchor, constant: -30).isActive = true
        audioText.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 150).isActive = true
        audioText.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 20).isActive = true
        audioText.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20).isActive = true
    }
}

protocol GenderClassifierDelegate {
    func displayPredictionResult(identifier: String, confidence: Double)
}

extension MainViewController: GenderClassifierDelegate {
    func displayPredictionResult(identifier: String, confidence: Double) {
        DispatchQueue.main.async {
            self.emotionText.text = ("감정: \(identifier)")
        }
    }
}

class ResultsObserver: NSObject, SNResultsObserving {
    var delegate: GenderClassifierDelegate?
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult,
              let classification = result.classifications.first else { return }
        
        let confidence = classification.confidence * 100.0
        
        delegate?.displayPredictionResult(identifier: classification.identifier, confidence: confidence)
        
    }
}
