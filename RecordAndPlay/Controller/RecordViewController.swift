//
//  RecordingFinalVC.swift
//  RecordAndPlay
//
//  Created by Girira Stephy on 27/02/21.
//

import UIKit
import AVFoundation
import Accelerate
import MediaPlayer

class RecordViewController: UIViewController{
    
    var playButton: UIButton!
    var recordButton: UIButton!
    var filePath : URL? = nil
    var audioEngine: AVAudioEngine!
    var audioFile : AVAudioFile!
    var audioFilePlayer: AVAudioPlayerNode!
    var isRec = false
    var isPlay = false
    var outref: ExtAudioFileRef?
    var audioView = AudioVisualizerView()
    private var recordingTs: Double = 0
    private var silenceTs: Double = 0
    var renderTs: Double = 0
    let settings = [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: true, AVSampleRateKey: Float64(44100), AVNumberOfChannelsKey: 1] as [String : Any]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        initViews()
        setupAudioView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let notificationName = AVAudioSession.interruptionNotification
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(notification:)), name: notificationName, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    

    @objc func recordButtonTapped(){
        if audioEngine != nil && audioEngine.isRunning {
            self.stopRecord()
        } else {
            self.checkPermissionAndRecord()
        }
    }
    
    func checkPermissionAndRecord() {
        let permission = AVAudioSession.sharedInstance().recordPermission
        switch permission {
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission({ (result) in
                DispatchQueue.main.async {
                    if result {
                        self.startRecord()
                    }
                    else {
                        self.showAlert(with: "Please give access to proceed")
                    }
                }
            })
            break
        case .granted:
            self.startRecord()
            break
        case .denied:
            self.showAlert(with: "Please give access to proceed")
            break
        default:
            break
        }
    }
    
    func format() -> AVAudioFormat? {
        let format = AVAudioFormat(settings: self.settings)
        return format
    }
    
    @objc func playButtonTapped(){
        
        if audioFilePlayer != nil && audioFilePlayer?.isPlaying ?? false {
            stopPlay()
        }else{
            startPlay()
        }
    }
    
    func updateRecordButton() {
        if isRec  {
            audioView.isHidden = false
            self.audioView.alpha = 1
            self.recordButton.setTitle("Stop recording", for: .normal)
            playButton.isEnabled = false
            playButton.setTitleColor(.gray, for: .normal)
        } else {
            audioView.isHidden = true
            self.audioView.alpha = 0
            self.recordButton.setTitle("Record", for: .normal)
            playButton.isEnabled = true
            playButton.setTitleColor(.blue, for: .normal)
        }
    }
    
    func updatePlayButton(){
        if isPlay{
            self.playButton.setTitle("Stop listening", for: .normal)
        } else{
            self.playButton.setTitle("Play", for: .normal)
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func showAlert(with message: String){
        let alert = UIAlertController.init(title: "Alert", message: message, preferredStyle: .alert)
        alert.view.tintColor = .white
        alert.addAction(UIAlertAction.init(title: "OK", style: .default, handler: { (_) in
            alert.dismiss(animated: true, completion: nil)
        }))
        self.present(alert, animated: true, completion: nil)
    }
}


//PLAYING
extension RecordViewController{
    func startPlay(){
        self.isPlay = true
        self.updatePlayButton()
        do{
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        }catch{
            print("Audio session for playBack failed")
        }
        
        if audioEngine == nil {
            audioEngine = AVAudioEngine()
        }
        
        if audioFilePlayer == nil {
            audioFilePlayer = AVAudioPlayerNode()
            audioEngine.attach(audioFilePlayer)
        }
        audioFile = try! AVAudioFile(forReading: filePath!)
        
        audioEngine.connect(audioFilePlayer, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)
        audioFilePlayer.scheduleSegment(audioFile, startingFrame: AVAudioFramePosition(0), frameCount: AVAudioFrameCount(audioFile.length) - UInt32(0), at: nil, completionHandler: self.completion)

        if !audioEngine.isRunning {
            try! audioEngine.start()
        }

        audioFilePlayer.installTap(onBus: 0, bufferSize: AVAudioFrameCount(audioFile.processingFormat.sampleRate), format: audioFile.processingFormat, block: {
            (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in

            // ...

        })
        audioFilePlayer.play()
    }
    
    func completion() {
        if audioFilePlayer != nil && audioFilePlayer.isPlaying {
            audioEngine.stop()
            audioEngine.mainMixerNode.removeTap(onBus: 0)
            audioFilePlayer.removeTap(onBus: 0)
            do{
                try AVAudioSession.sharedInstance().setActive(false)
            }catch{
                
            }
            DispatchQueue.main.async {
                self.isPlay = false
                self.updatePlayButton()
            }
            
        }
    }
    
    func stopPlay() {
        if audioFilePlayer != nil && audioFilePlayer.isPlaying {
            audioFilePlayer.stop()
        }
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.mainMixerNode.removeTap(onBus: 0)
            audioFilePlayer.removeTap(onBus: 0)
        }
        do{
            try AVAudioSession.sharedInstance().setActive(false)
        }catch{
            
        }
        DispatchQueue.main.async {
            self.isPlay = false
            self.updatePlayButton()
        }
    }
}

//recording
extension RecordViewController{
    func startRecord(){
        self.isRec = true
        self.updateRecordButton()
        
        self.recordingTs = NSDate().timeIntervalSince1970
        self.silenceTs = 0
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch let error as NSError {
            print(error.localizedDescription)
            return
        }
        
        if audioEngine == nil {
            audioEngine = AVAudioEngine()
        }
        
        let inputNode = self.audioEngine.inputNode
        guard let format = self.format() else {
            return
        }
        self.filePath = self.getDocumentsDirectory().appendingPathComponent("saregamapa.wav")
        guard let outUrl = self.filePath else { return}
        _ = ExtAudioFileCreateWithURL(outUrl as CFURL,
            kAudioFileWAVEType,
            format.streamDescription,
            nil,
            AudioFileFlags.eraseFile.rawValue,
            &self.outref)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { (buffer, time) in
            let level: Float = -50
            let length: UInt32 = 1024
            buffer.frameLength = length
            let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
            var value: Float = 0
            vDSP_meamgv(channels[0], 1, &value, vDSP_Length(length))
            var average: Float = ((value == 0) ? -100 : 20.0 * log10f(value))
            if average > 0 {
                average = 0
            } else if average < -100 {
                average = -100
            }
            let silent = average < level
            let ts = NSDate().timeIntervalSince1970
            if ts - self.renderTs > 0.1 {
                let floats = UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength))
                let frame = floats.map({ (f) -> Int in
                    return Int(f * Float(Int16.max))
                })
                DispatchQueue.main.async {
                    self.renderTs = ts
                    let len = self.audioView.waveforms.count
                    for i in 0 ..< len {
                        let idx = ((frame.count - 1) * i) / len
                        let f: Float = sqrt(1.5 * abs(Float(frame[idx])) / Float(Int16.max))
                        self.audioView.waveforms[i] = min(49, Int(f * 50))
                    }
                    self.audioView.active = !silent
                    self.audioView.setNeedsDisplay()
                }
            }
            
            _ = ExtAudioFileWrite(self.outref!, buffer.frameLength, buffer.audioBufferList)
        }
        do {
            self.audioEngine.prepare()
            try self.audioEngine.start()
        } catch let error as NSError {
            print(error.localizedDescription)
            return
        }
        
    }

    func stopRecord(){
        if  audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            ExtAudioFileDispose(self.outref!)
            do {
                try AVAudioSession.sharedInstance().setActive(false)
            } catch  let error as NSError {
                print(error.localizedDescription)
                return
            }
            self.isRec = false
            self.updateRecordButton()
        }
    }
}

//UI
extension RecordViewController{
    func initViews(){
        recordButton = UIButton()
        view.addSubview(recordButton)
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 54).isActive = true
        recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0).isActive = true
        recordButton.setTitle("Record", for: .normal)
        recordButton.setTitleColor(.blue, for: .normal)
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        
        playButton = UIButton()
        view.addSubview(playButton)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.topAnchor.constraint(equalTo: recordButton.bottomAnchor, constant: 24).isActive = true
        playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0).isActive = true
        playButton.setTitle("Play", for: .normal)
        playButton.isEnabled = false
        playButton.setTitleColor(.gray, for: .normal)
        playButton.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
    }
    
    func setupAudioView() {
        view.addSubview(audioView)
        audioView.translatesAutoresizingMaskIntoConstraints = false
        audioView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0).isActive = true
        audioView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -36).isActive = true
        audioView.widthAnchor.constraint(equalToConstant: view.frame.width).isActive = true
        audioView.heightAnchor.constraint(equalToConstant: 135).isActive = true
        audioView.alpha = 0
        audioView.isHidden = true
    }
    
}


extension RecordViewController{
    
    @objc func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        guard let key = userInfo[AVAudioSessionInterruptionTypeKey] as? NSNumber
            else { return }
        if key.intValue == 1 {
            DispatchQueue.main.async {
                if self.audioEngine.isRunning {
                    self.stopRecord()
                }
            }
        }
    }
}
