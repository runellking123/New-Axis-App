import SwiftUI

struct TravelAgentsView: View {
    @State private var searchText = ""
    @State private var selectedService: TravelService? = nil
    @State private var currentPage = 0
    @State private var selectedAgent: TravelAgent? = nil
    private let perPage = 25

    var body: some View {
        VStack(spacing: 0) {
            // Service filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip("All", isSelected: selectedService == nil) {
                        selectedService = nil
                        currentPage = 0
                    }
                    ForEach([TravelService.luxury, .honeymoon, .cruises, .adventure, .family, .group, .corporate, .budget, .heritage], id: \.self) { svc in
                        filterChip(svc.rawValue, isSelected: selectedService == svc) {
                            selectedService = svc
                            currentPage = 0
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            // Search
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search agents, cities, services...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, _ in currentPage = 0 }
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Results
            let filtered = filteredAgents
            let totalPages = max(1, Int(ceil(Double(filtered.count) / Double(perPage))))
            let startIdx = min(currentPage * perPage, filtered.count)
            let endIdx = min(startIdx + perPage, filtered.count)
            let pageAgents = startIdx < endIdx ? Array(filtered[startIdx..<endIdx]) : []

            ScrollView {
                LazyVStack(spacing: 10) {
                    // Count + page info
                    HStack {
                        Text("\(filtered.count) agents found")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Page \(currentPage + 1) of \(totalPages)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)

                    ForEach(pageAgents) { agent in
                        agentCard(agent)
                    }

                    // Pagination
                    if filtered.count > perPage {
                        HStack(spacing: 16) {
                            Button {
                                if currentPage > 0 { currentPage -= 1 }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Previous")
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(currentPage > 0 ? Color.axisGold : .gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(currentPage > 0 ? Color.axisGold.opacity(0.12) : Color(.systemGray5))
                                .clipShape(Capsule())
                            }
                            .disabled(currentPage == 0)

                            Text("Page \(currentPage + 1) of \(totalPages)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 80)

                            Button {
                                if currentPage < totalPages - 1 { currentPage += 1 }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Next")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(currentPage < totalPages - 1 ? Color.axisGold : .gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(currentPage < totalPages - 1 ? Color.axisGold.opacity(0.12) : Color(.systemGray5))
                                .clipShape(Capsule())
                            }
                            .disabled(currentPage >= totalPages - 1)
                        }
                        .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .sheet(item: $selectedAgent) { agent in
            AgentDetailView(agent: agent)
        }
    }

    // MARK: - Filtered Agents

    private var filteredAgents: [TravelAgent] {
        var results = TravelAgentsData.allAgents
        if let svc = selectedService {
            results = results.filter { $0.services.contains(svc) }
        }
        if !searchText.isEmpty {
            results = TravelAgentsData.search(query: searchText)
            if let svc = selectedService {
                results = results.filter { $0.services.contains(svc) }
            }
        }
        return results
    }

    // MARK: - Agent Card

    private func agentCard(_ agent: TravelAgent) -> some View {
        Button { selectedAgent = agent } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(agent.agencyName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        if let owner = agent.ownerName, !owner.isEmpty {
                            Text(owner)
                                .font(.caption)
                                .foregroundStyle(Color.axisGold)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(agent.city), \(agent.state)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Services tags
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(agent.services.prefix(4)) { svc in
                            Text(svc.rawValue)
                                .font(.system(size: 9))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.axisGold.opacity(0.1))
                                .foregroundStyle(Color.axisGold)
                                .clipShape(Capsule())
                        }
                        if agent.services.count > 4 {
                            Text("+\(agent.services.count - 4)")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Text(agent.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func filterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color.axisGold : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .secondary)
                .clipShape(.capsule)
        }
    }
}

// MARK: - Agent Detail View

struct AgentDetailView: View {
    let agent: TravelAgent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text(agent.agencyName)
                            .font(.title2.bold())
                        if let owner = agent.ownerName, !owner.isEmpty {
                            Text(owner)
                                .font(.subheadline)
                                .foregroundStyle(Color.axisGold)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.secondary)
                            Text("\(agent.city), \(agent.state)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Contact info
                    VStack(spacing: 10) {
                        if let phone = agent.phone, !phone.isEmpty {
                            contactRow(icon: "phone.fill", label: phone, color: .green) {
                                if let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: ""))") {
                                    PlatformServices.openURL(url)
                                }
                            }
                        }
                        if let email = agent.email, !email.isEmpty {
                            contactRow(icon: "envelope.fill", label: email, color: .blue) {
                                if let url = URL(string: "mailto:\(email)") {
                                    PlatformServices.openURL(url)
                                }
                            }
                        }
                        contactRow(icon: "globe", label: agent.website, color: Color.axisGold) {
                            var urlStr = agent.website
                            if !urlStr.hasPrefix("http") { urlStr = "https://\(urlStr)" }
                            if let url = URL(string: urlStr) {
                                PlatformServices.openURL(url)
                            }
                        }
                    }
                    .padding(14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("About")
                            .font(.headline)
                        Text(agent.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Services
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Services")
                            .font(.headline)
                        FlowLayout(spacing: 6) {
                            ForEach(agent.services) { svc in
                                Text(svc.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.axisGold.opacity(0.12))
                                    .foregroundStyle(Color.axisGold)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    // Specialties
                    if let specialties = agent.specialties, !specialties.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Specialties")
                                .font(.headline)
                            Text(specialties)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Share button
                    Button {
                        shareAgent()
                    } label: {
                        Label("Share Agent Info", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.axisGold)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.axisGold.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func contactRow(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func shareAgent() {
        var text = "\(agent.agencyName)\n"
        if let owner = agent.ownerName, !owner.isEmpty { text += "\(owner)\n" }
        text += "\(agent.city), \(agent.state)\n"
        if let phone = agent.phone, !phone.isEmpty { text += "Phone: \(phone)\n" }
        if let email = agent.email, !email.isEmpty { text += "Email: \(email)\n" }
        text += "Website: \(agent.website)\n"
        text += "\nServices: \(agent.services.map(\.rawValue).joined(separator: ", "))\n"
        if let spec = agent.specialties, !spec.isEmpty { text += "\nSpecialties: \(spec)\n" }

        PlatformServices.share(items: [text])
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

#Preview {
    TravelAgentsView()
}
