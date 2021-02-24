//
//  RecordViewController.swift
//  RecordAndPlay
//
//  Created by Girira Stephy on 24/02/21.
//

import Foundation
import UIKit
import AVFoundation
import MediaPlayer

class RecordViewController: UIViewController{
    
    var playButton: UIButton!
    var recordButton: UIButton!
    var waveView: UIView!
    var audioEngine : AVAudioEngine!
    var audioFile : AVAudioFile!
    var audioPlayer : AVAudioPlayerNode!
    var outref: ExtAudioFileRef?
    var audioFilePlayer: AVAudioPlayerNode!
    var filePath : URL? = nil
    var isRec = false
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        initViews()
    }
    
    
    
    
    @objc func recordButtonTapped(){
        
        if audioEngine != nil && audioEngine.isRunning {
            self.stopRecord()
        } else {
            self.startRecord()
        }
    }
    
    func startRecord() {
        self.isRec = true
        self.update()
        filePath =  getDocumentsDirectory().appendingPathComponent("recording.wav")
        do{
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord)
            try AVAudioSession.sharedInstance().setActive(true)
        }catch{
            print("Error in creating AVAudio session")
        }
        if audioEngine == nil {
            audioEngine = AVAudioEngine()
        }
        
        let format = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
                                                     sampleRate: 44100.0,
                                                     channels: 1,
                                                     interleaved: true)

        let downFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
                                                     sampleRate: 16000.0,
                                                     channels: 1,
                                                     interleaved: true)

        audioEngine.connect(audioEngine.inputNode, to: audioEngine.mainMixerNode, format: format)
        guard let outUrl = filePath else { return}
        _ = ExtAudioFileCreateWithURL(outUrl as CFURL,
            kAudioFileWAVEType,
            downFormat!.streamDescription,
            nil,
            AudioFileFlags.eraseFile.rawValue,
            &outref)
        
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(format!.sampleRate * 0.4), format: format, block: { (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in

            let converter = AVAudioConverter.init(from: format!, to: downFormat!)
            let newbuffer = AVAudioPCMBuffer(pcmFormat: downFormat!,
                                             frameCapacity: AVAudioFrameCount(downFormat!.sampleRate * 0.4))
            let inputBlock : AVAudioConverterInputBlock = { (inNumPackets, outStatus) -> AVAudioBuffer? in
                outStatus.pointee = AVAudioConverterInputStatus.haveData
                let audioBuffer : AVAudioBuffer = buffer
                return audioBuffer
            }
            var error : NSError?
            converter!.convert(to: newbuffer!, error: &error, withInputFrom: inputBlock)
            _ = ExtAudioFileWrite(self.outref!, newbuffer!.frameLength, newbuffer!.audioBufferList)
        })
        
        do{
            try audioEngine.start()
        }catch{
            print("couldnt start audio engine")
        }
    }
    
    
    func stopRecord() {

        if audioEngine != nil && audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            ExtAudioFileDispose(self.outref!)
            try! AVAudioSession.sharedInstance().setActive(false)
            self.isRec = false
            self.update()
        }
    }
    
    func update() {
        if isRec  {
            self.recordButton.setTitle("Stop", for: .normal)
        } else {
            self.recordButton.setTitle("Record", for: .normal)
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    
    func playButtonTapped(){
        
    }
}


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
}
