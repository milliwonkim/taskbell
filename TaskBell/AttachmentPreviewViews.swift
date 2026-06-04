//
//  AttachmentPreviewViews.swift
//  TaskBell
//

import AVKit
import SwiftUI
import UIKit

struct PhotoAttachmentPreview: Identifiable {
    let id: UUID
    let fileName: String
    let image: UIImage

    init?(attachment: TodoAttachmentDraft) {
        guard attachment.kind == .photo, let image = UIImage(data: attachment.data) else {
            return nil
        }

        self.id = attachment.id
        self.fileName = attachment.fileName
        self.image = image
    }
}

struct PhotoAttachmentPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var appLanguage
    let preview: PhotoAttachmentPreview

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                ZoomableImageView(image: preview.image)
                    .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle(preview.fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appLanguage.text(korean: "닫기", english: "Close")) {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black.opacity(0.85), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

struct VideoAttachmentPreview: Identifiable {
    let id: UUID
    let fileName: String
    let url: URL

    init?(attachment: TodoAttachmentDraft) {
        guard attachment.kind == .video else {
            return nil
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TaskBellVideoPreviews", isDirectory: true)
        let sanitizedFileName = attachment.fileName.replacingOccurrences(of: "/", with: "-")
        let url = directory.appendingPathComponent("\(attachment.id.uuidString)-\(sanitizedFileName)")

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try attachment.data.write(to: url, options: [.atomic])
        } catch {
            return nil
        }

        self.id = attachment.id
        self.fileName = attachment.fileName
        self.url = url
    }
}

struct VideoAttachmentPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var appLanguage
    let preview: VideoAttachmentPreview
    @State private var player: AVPlayer

    init(preview: VideoAttachmentPreview) {
        self.preview = preview
        _player = State(initialValue: AVPlayer(url: preview.url))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VideoPlayer(player: player)
                    .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle(preview.fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appLanguage.text(korean: "닫기", english: "Close")) {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black.opacity(0.85), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                player.play()
            }
            .onDisappear {
                player.pause()
            }
        }
    }
}

private struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .black

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }
    }
}
