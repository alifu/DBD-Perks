//
//  CatalogCardView.swift
//  DBD Perks
//

import SwiftUI
import NukeUI

/// One perk or add-on in the catalog: icon, name, who it belongs to, and the description.
struct CatalogCardView: View {
    let entry: CatalogEntry
    var showsDescription = true

    private let iconSize: CGFloat = 56

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                if showsDescription { Text(description).font(.callout) }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var icon: some View {
        Group {
            if let bundled = bundledIcon {
                Image(uiImage: bundled).resizable().scaledToFit()
            } else {
                LazyImage(url: iconURL) { state in
                    if let image = state.image {
                        image.resizable().scaledToFit()
                    } else {
                        placeholderColor
                    }
                }
            }
        }
        .frame(width: iconSize, height: iconSize)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var bundledIcon: UIImage? {
        switch entry {
        case .perk(let perk): return PerkIconStore.image(forPerkID: perk.id)
        case .addon(let addon): return AddonIconStore.image(forIconStem: addon.iconStem)
        }
    }

    private var title: String { entry.name }

    private var description: String {
        switch entry {
        case .perk(let perk): return perk.description
        case .addon(let addon): return addon.description
        }
    }

    private var iconURL: URL? {
        switch entry {
        case .perk(let perk): return perk.iconUrl
        case .addon(let addon): return addon.iconUrl
        }
    }

    private var subtitle: String {
        switch entry {
        case .perk(let perk):
            let role = perk.role.rawValue.capitalized
            return perk.owner.isEmpty ? "Perk · \(role) · Generic" : "Perk · \(role) · \(perk.owner)"
        case .addon(let addon):
            let owner = addon.ownerName.isEmpty ? addon.parent.capitalized : addon.ownerName
            return ["Add-on", owner, addon.rarity.title].filter { !$0.isEmpty }.joined(separator: " · ")
        }
    }

    /// Add-ons get the rarity colour of the game; perks and unknown rarities stay neutral.
    private var placeholderColor: Color {
        guard case .addon(let addon) = entry else { return Color.gray.opacity(0.3) }
        switch addon.rarity {
        case .none: return Color.gray.opacity(0.3)
        case .common: return Color(red: 0.55, green: 0.42, blue: 0.25)
        case .uncommon: return Color(red: 0.85, green: 0.75, blue: 0.25)
        case .rare: return Color(red: 0.3, green: 0.7, blue: 0.35)
        case .veryRare: return Color(red: 0.6, green: 0.3, blue: 0.8)
        case .visceral: return Color(red: 0.8, green: 0.2, blue: 0.25)
        }
    }
}
