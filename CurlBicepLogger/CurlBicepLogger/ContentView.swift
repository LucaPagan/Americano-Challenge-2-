//
//  ContentView.swift
//  CurlBicepLogger
//
//  Created by Luca Pagano on 11/11/25.
//

import SwiftUI
import LinkPresentation
import UniformTypeIdentifiers

struct ContentView: View {
    
    @StateObject private var fileReceiver = FileReceiver()
    @State private var isShowingShareSheet = false
    
    var body: some View {
        NavigationView {
            
            List {
                Section(
                    header: Text("Registered Data").fontWeight(.medium),
                    
                    footer: Text(fileReceiver.statusMessage)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .center)
                ) {
                    
                    if fileReceiver.receivedFiles.isEmpty {
                        Text("No files received from the Apple Watch.")
                            .foregroundColor(.secondary)
                            .padding(.vertical)
                    } else {
                        ForEach(fileReceiver.receivedFiles, id: \.self) { url in
                            Label(url.lastPathComponent, systemImage: "doc.text.fill")
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Data Files Received")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        self.isShowingShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(fileReceiver.receivedFiles.isEmpty)
                }
            }
            .sheet(isPresented: $isShowingShareSheet, onDismiss: {
                isShowingShareSheet = false
            }) {
                let activityItems = fileReceiver.receivedFiles.map { url in
                    return CSVActivityItemSource(fileURL: url)
                }
                ShareSheet(activityItems: activityItems)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

class CSVActivityItemSource: NSObject, UIActivityItemSource {
    
    let fileURL: URL
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return Data()
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            print("Failed to read data for sharing: \(error)")
            return nil
        }
    }
    
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = self.fileURL.lastPathComponent
        
        let fileIcon = UIImage(systemName: "doc.text")
        metadata.iconProvider = NSItemProvider(object: fileIcon!)
        
        return metadata
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        if #available(iOS 14.0, *) {
            return UTType.commaSeparatedText.identifier
        } else {
            return "public.comma-separated-values-text"
        }
    }
}


#Preview {
    ContentView()
}
