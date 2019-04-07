//
//  DownSampler.swift
//
//
//  Created by Zain Haq on 2017-04-16.
//

import Foundation
import AVFoundation

/**
 Downsamples audio file at url
 
 - Parameter url: string url of sound file on disk
 - Parameter outputUrl: destination url of output
 - Parameter outputFrequency: frequency to downsample to
 - Parameter completionHandler: block that is invoked on succesful export on the main thread
 */
func downSampleFile(atUrl url: String, outputUrl: String, outputFrequency: Double, completionHandler: @escaping () -> Void) {
    let fileUrl = URL(fileURLWithPath: url)
    let outputfileUrl = URL(fileURLWithPath: outputUrl)
    
    let asset = AVAsset(url: fileUrl)
    
    var assetWriter: AVAssetWriter
    var assetReader: AVAssetReader
    
    do {
        assetWriter = try AVAssetWriter(outputURL: outputfileUrl, fileType: AVFileTypeAppleM4A)
        assetReader = try AVAssetReader(asset: asset)
    } catch let error {
        fatalError("unable to create asset writer? error: \(error)")
    }
    
    let audioOutputSettings: [String : Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: outputFrequency,
        AVEncoderBitRateKey: 16000,
        AVNumberOfChannelsKey: 1
    ]
    
    let audioInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioOutputSettings)
    audioInput.expectsMediaDataInRealTime = false
    
    assetWriter.add(audioInput)
    
    let readerSettings: [String : Any] = [AVFormatIDKey: Int(kAudioFormatLinearPCM)]
    
    let track = asset.tracks(withMediaType: AVMediaTypeAudio)[0]
    let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: readerSettings)
    readerOutput.alwaysCopiesSampleData = false
    assetReader.add(readerOutput)
    
    assetReader.startReading()
    assetWriter.startWriting()
    assetWriter.startSession(atSourceTime: kCMTimeZero)
    
    let queue = DispatchQueue(label: "Downsample Queue")
    audioInput.requestMediaDataWhenReady(on: queue) {
        while audioInput.isReadyForMoreMediaData {
            
            if assetReader.status == .reading, let nextBuffer = readerOutput.copyNextSampleBuffer() {
                audioInput.append(nextBuffer)
            } else {
                audioInput.markAsFinished()
                
                switch assetReader.status {
                case .completed:
                    assetWriter.endSession(atSourceTime: asset.duration)
                    assetWriter.finishWriting {
                        print("Finished downsampling audio at url: \(url)")
                        DispatchQueue.main.async {
                            completionHandler()
                        }
                    }
                default:
                    print("Failed to downsample audio at url: \(url)")
                }
                
            }
        }
    }
}

