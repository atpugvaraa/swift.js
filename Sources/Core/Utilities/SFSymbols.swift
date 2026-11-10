/// SF Symbol names -> Lucide icon components (lucide-react, ISC). Outline icons: `.fill`
/// variants map to the same icon. Unknown names are reported rather than guessed.
enum SFSymbols {
    static func lucideIcon(for symbol: String) -> String? {
        let base = symbol.hasSuffix(".fill") ? String(symbol.dropLast(".fill".count)) : symbol
        return table[base].map { $0 + "Icon" }
    }

    private static let table: [String: String] = [
        "circle": "Circle", "checkmark.circle": "CircleCheck", "checkmark": "Check",
        "xmark": "X", "xmark.circle": "CircleX", "plus": "Plus", "plus.circle": "CirclePlus",
        "minus": "Minus", "trash": "Trash2", "pencil": "Pencil", "square.and.pencil": "SquarePen",
        "star": "Star", "heart": "Heart", "gear": "Settings", "gearshape": "Settings",
        "person": "User", "person.2": "Users", "house": "House", "magnifyingglass": "Search",
        "chevron.right": "ChevronRight", "chevron.left": "ChevronLeft", "chevron.up": "ChevronUp",
        "chevron.down": "ChevronDown", "arrow.right": "ArrowRight", "arrow.left": "ArrowLeft",
        "arrow.up": "ArrowUp", "arrow.down": "ArrowDown", "bell": "Bell", "envelope": "Mail",
        "calendar": "Calendar", "clock": "Clock", "info.circle": "Info",
        "exclamationmark.triangle": "TriangleAlert", "exclamationmark.circle": "CircleAlert",
        "square.and.arrow.up": "Share", "ellipsis": "Ellipsis", "line.3.horizontal": "Menu",
        "bookmark": "Bookmark", "cart": "ShoppingCart", "photo": "Image", "list.bullet": "List",
        "sun.max": "Sun", "moon": "Moon", "globe": "Globe", "lock": "Lock", "folder": "Folder",
        "doc": "File", "phone": "Phone", "mappin": "MapPin", "camera": "Camera", "play": "Play",
        "pause": "Pause", "arrow.clockwise": "RotateCw", "link": "Link", "square": "Square",
        "checkmark.square": "SquareCheck", "flag": "Flag", "tag": "Tag", "tray": "Inbox",
        "paperplane": "Send",
    ]
}
