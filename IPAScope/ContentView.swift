
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var archive: IPAArchive?
    @State private var showingImporter = false
    @State private var searchText = ""
    @State private var selectedFile: IPAFile?
    @State private var textContent = ""
    @State private var errorMessage: String?
    @State private var isShowingText = false
    @State private var isLoading = false

    private var filteredFiles: [IPAFile] {
        let files = archive?.files ?? []

        if searchText.isEmpty {
            return files
        }

        return files.filter {
            $0.path.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let archive {
                    mainContent(archive)
                } else {
                    emptyState
                }
            }
            .navigationTitle("IPAScope")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingImporter = true
                    } label: {
                        Label(
                            "IPAを開く",
                            systemImage: "folder.badge.plus"
                        )
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [
                    UTType(filenameExtension: "ipa") ?? .zip,
                    .zip
                ],
                allowsMultipleSelection: false,
                onCompletion: importResult
            )
            .sheet(isPresented: $isShowingText) {
                textViewer
            }
            .alert(
                "エラー",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: {
                        if !$0 {
                            errorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .overlay {
                if isLoading {
                    ProgressView("解析中…")
                        .padding(24)
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                }
            }
        }
        .tint(.cyan)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(
                systemName: "shippingbox.and.arrow.backward.fill"
            )
            .font(.system(size: 58))
            .foregroundStyle(.cyan)

            Text("IPAファイルを解析")
                .font(.title2.bold())

            Text(
                "IPAを選ぶと、アプリ情報・内部ファイル一覧・"
                + "テキストファイルを確認できます。"
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 28)

            Button {
                showingImporter = true
            } label: {
                Label(
                    "IPAを選択",
                    systemImage: "doc.badge.plus"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    .cyan,
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .foregroundStyle(.black)
            }
            .padding(.horizontal, 28)
        }
    }

    private func mainContent(
        _ archive: IPAArchive
    ) -> some View {
        List {
            Section("アプリ情報") {
                HStack(spacing: 12) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 30))
                        .foregroundStyle(.cyan)
                        .frame(width: 52, height: 52)
                        .background(
                            .cyan.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 13)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(archive.metadata.name)
                            .font(.headline)
                            .lineLimit(2)

                        Text(archive.url.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 6)

                metadataRow(
                    "Bundle ID",
                    value: archive.metadata.bundleID
                )

                metadataRow(
                    "バージョン",
                    value: archive.metadata.version
                )

                metadataRow(
                    "ビルド番号",
                    value: archive.metadata.build
                )
            }

            Section("アーカイブ") {
                LabeledContent(
                    "ファイル数",
                    value: "\(archive.files.count)"
                )

                LabeledContent(
                    "テキスト表示",
                    value: "UTF-8 / UTF-16"
                )
            }

            Section("内部ファイル") {
                if filteredFiles.isEmpty {
                    ContentUnavailableView.search(
                        text: searchText
                    )
                } else {
                    ForEach(filteredFiles) { file in
                        Button {
                            openFile(file, in: archive)
                        } label: {
                            HStack(spacing: 10) {
                                Image(
                                    systemName: iconName(for: file)
                                )
                                .foregroundStyle(
                                    file.isDirectory
                                    ? .cyan
                                    : .secondary
                                )
                                .frame(width: 22)

                                VStack(
                                    alignment: .leading,
                                    spacing: 3
                                ) {
                                    Text(
                                        file.name.isEmpty
                                        ? file.path
                                        : file.name
                                    )
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                    Text(file.path)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 4)

                                if !file.isDirectory {
                                    Text(
                                        ByteCountFormatter
                                            .string(
                                                fromByteCount:
                                                    Int64(file.size),
                                                countStyle: .file
                                            )
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            } footer: {
                Text(
                    "読める形式のテキストファイルをタップすると"
                    + "内容を表示します。バイナリや大きなファイルは"
                    + "表示できない場合があります。"
                )
            }
        }
        .searchable(
            text: $searchText,
            prompt: "ファイル名・パスを検索"
        )
        .listStyle(.insetGrouped)
    }

    private func metadataRow(
        _ title: String,
        value: String
    ) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private var textViewer: some View {
        NavigationStack {
            ScrollView {
                Text(textContent)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .textSelection(.enabled)
                    .padding()
            }
            .navigationTitle(
                selectedFile?.name ?? "ファイル内容"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        isShowingText = false
                    }
                }
            }
        }
    }

    private func importResult(
        _ result: Result<[URL], Error>
    ) {
        switch result {
        case .success(let urls):
            guard let picked = urls.first else {
                return
            }

            isLoading = true

            Task {
                defer {
                    isLoading = false
                }

                let access =
                    picked.startAccessingSecurityScopedResource()

                defer {
                    if access {
                        picked.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    let destination =
                        FileManager.default.temporaryDirectory
                            .appendingPathComponent(
                                UUID().uuidString
                                + "-"
                                + picked.lastPathComponent
                            )

                    try FileManager.default.copyItem(
                        at: picked,
                        to: destination
                    )

                    let loaded = try IPAArchive(url: destination)

                    await MainActor.run {
                        archive = loaded
                        searchText = ""
                        selectedFile = nil
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                    }
                }
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func openFile(
        _ file: IPAFile,
        in archive: IPAArchive
    ) {
        guard !file.isDirectory else {
            return
        }

        let ext = URL(fileURLWithPath: file.path)
            .pathExtension.lowercased()

        let supported: Set<String> = [
            "txt", "json", "xml", "plist", "strings",
            "html", "css", "js", "swift", "m", "h",
            "sh", "md", "yaml", "yml", "entitlements",
            "mobileprovision", "log", "csv", "conf", "ini"
        ]

        guard supported.contains(ext)
                || file.name == "Info.plist" else {
            errorMessage =
                "この種類のファイルはテキスト表示の対象外です。"
            return
        }

        do {
            textContent = try archive.readTextFile(
                path: file.path
            )
            selectedFile = file
            isShowingText = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func iconName(for file: IPAFile) -> String {
        if file.isDirectory {
            return "folder.fill"
        }

        switch URL(fileURLWithPath: file.path)
            .pathExtension.lowercased() {
        case "plist", "entitlements":
            return "list.clipboard"
        case "png", "jpg", "jpeg", "heic", "pdf":
            return "photo"
        case "dylib", "framework", "so":
            return "gearshape.2"
        case "json", "xml", "strings", "txt", "swift", "m", "h":
            return "doc.text"
        default:
            return "doc"
        }
    }
}
