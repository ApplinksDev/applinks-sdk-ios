import SwiftUI
import AppLinksSDK

struct LinkCreatorView: View {
    @State private var domain = "example.onapp.link"
    @State private var title = "My Awesome Link"
    @State private var deepLinkPath = "/product/123"
    @State private var originalUrl = "https://example.com/product/123"
    @State private var deepLinkParams = "campaign=summer,discount=25"
    @State private var selectedPathType = LinkPathType.unguessable
    @State private var isCreating = false
    @State private var createdLink: CreatedLink?
    @State private var errorMessage: String?
    @State private var showingCopiedAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Link Configuration")) {
                    TextField("Domain", text: $domain)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Title", text: $title)
                    
                    TextField("Deep Link Path", text: $deepLinkPath)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Original URL (optional)", text: $originalUrl)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Parameters (key=value,key2=value2)", text: $deepLinkParams)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Picker("Path Type", selection: $selectedPathType) {
                        Text("Unguessable (32 chars)").tag(LinkPathType.unguessable)
                        Text("Short (4-6 chars)").tag(LinkPathType.short)
                    }
                }
                
                Section {
                    Button(action: createLink) {
                        if isCreating {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                                Text("Creating...")
                                    .padding(.leading, 8)
                            }
                        } else {
                            Text("Create Link")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(isCreating || domain.isEmpty || title.isEmpty || deepLinkPath.isEmpty)
                }
                
                if let error = errorMessage {
                    Section(header: Text("Error")) {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                if let link = createdLink {
                    Section(header: Text("Created Link")) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("URL:")
                                    .fontWeight(.medium)
                                Text(link.fullUrl)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            
                            HStack {
                                Text("Path:")
                                    .fontWeight(.medium)
                                Text(link.aliasPath)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Button(action: {
                                UIPasteboard.general.string = link.fullUrl
                                showingCopiedAlert = true
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showingCopiedAlert = false
                                }
                            }) {
                                HStack {
                                    Image(systemName: showingCopiedAlert ? "checkmark.circle.fill" : "doc.on.doc")
                                    Text(showingCopiedAlert ? "Copied!" : "Copy Link")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(showingCopiedAlert ? Color.green : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .navigationTitle("Create Link")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func createLink() {
        isCreating = true
        errorMessage = nil
        createdLink = nil
        
        // Parse parameters
        let params = parseParameters(deepLinkParams)
        
        Task {
            do {
                let link = try await AppLinksSDK.shared.linkShortener.createLink(
                    domain: domain,
                    title: title,
                    deepLinkPath: deepLinkPath,
                    originalUrl: originalUrl.isEmpty ? nil : originalUrl,
                    deepLinkParams: params.isEmpty ? nil : params,
                    pathType: selectedPathType
                )
                
                await MainActor.run {
                    createdLink = link
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
    
    private func parseParameters(_ paramString: String) -> [String: String] {
        guard !paramString.isEmpty else { return [:] }
        
        var params: [String: String] = [:]
        let pairs = paramString.split(separator: ",")
        
        for pair in pairs {
            let keyValue = pair.split(separator: "=")
            if keyValue.count == 2 {
                let key = String(keyValue[0]).trimmingCharacters(in: .whitespaces)
                let value = String(keyValue[1]).trimmingCharacters(in: .whitespaces)
                params[key] = value
            }
        }
        
        return params
    }
}