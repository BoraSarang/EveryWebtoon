import Foundation

enum SidebarSection: String, CaseIterable {
    case discover = "DISCOVER"
    case library = "LIBRARY"
}

struct SidebarItem: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let section: SidebarSection
    let platform: String?
    let category: String?
    let params: [String: String]
    let children: [SidebarItem]

    init(id: String, title: String, icon: String, section: SidebarSection,
         platform: String? = nil, category: String? = nil,
         params: [String: String] = [:], children: [SidebarItem] = []) {
        self.id = id
        self.title = title
        self.icon = icon
        self.section = section
        self.platform = platform
        self.category = category
        self.params = params
        self.children = children
    }

    var isGroup: Bool { !children.isEmpty }

    var childItems: [SidebarItem]? { children.isEmpty ? nil : children }
}

extension SidebarItem {
    static let weekdays: [SidebarItem] = [
        ("mon", "월요일"), ("tue", "화요일"), ("wed", "수요일"), ("thu", "목요일"),
        ("fri", "금요일"), ("sat", "토요일"), ("sun", "일요일"),
    ].map { day, title in
        SidebarItem(id: "naver-week-\(day)", title: title, icon: "calendar.day",
                    section: .discover, platform: "naver", category: "weekday",
                    params: ["week": day])
    }

    static let naverGenres: [SidebarItem] = [
        ("PURE", "로맨스"), ("FANTASY", "판타지"), ("ACTION", "액션"),
        ("DAILY", "일상"), ("THRILL", "스릴러"), ("COMIC", "개그"),
        ("HISTORICAL", "무협/사극"), ("DRAMA", "드라마"),
        ("SENSIBILITY", "감성"), ("SPORTS", "스포츠"),
    ].map { genre, title in
        SidebarItem(id: "naver-genre-\(genre)", title: title, icon: "tag",
                    section: .discover, platform: "naver", category: "genre",
                    params: ["genre": genre])
    }

    static let naver = SidebarItem(
        id: "naver", title: "네이버", icon: "n.square", section: .discover,
        platform: "naver",
        children: [
            SidebarItem(id: "naver-week", title: "요일별", icon: "calendar",
                        section: .discover, children: weekdays),
            SidebarItem(id: "naver-genre", title: "장르별", icon: "tag",
                        section: .discover, children: naverGenres),
            SidebarItem(id: "naver-best", title: "베스트 도전", icon: "flame",
                        section: .discover, platform: "naver", category: "best_challenge"),
            SidebarItem(id: "naver-ranking", title: "랭킹", icon: "chart.bar",
                        section: .discover, platform: "naver", category: "ranking"),
            SidebarItem(id: "naver-finished", title: "완결", icon: "checkmark.seal",
                        section: .discover, platform: "naver", category: "finished"),
        ]
    )

    static let kakaoWeekdays: [SidebarItem] = [
        ("1", "월요일"), ("2", "화요일"), ("3", "수요일"), ("4", "목요일"),
        ("5", "금요일"), ("6", "토요일"), ("7", "일요일"),
    ].map { day, title in
        SidebarItem(id: "kakao-week-\(day)", title: title, icon: "calendar.day",
                    section: .discover, platform: "kakao", category: "weekday",
                    params: ["week": day])
    }

    static let kakaoGenres: [SidebarItem] = [
        ("0", "전체"), ("115", "판타지"), ("116", "드라마"), ("121", "로맨스"),
        ("69", "로판"), ("112", "무협"), ("122", "액션"), ("119", "BL"),
    ].map { genre, title in
        SidebarItem(id: "kakao-genre-\(genre)", title: title, icon: "tag",
                    section: .discover, platform: "kakao", category: "genre",
                    params: ["genre": genre])
    }

    static let kakao = SidebarItem(
        id: "kakao", title: "카카오", icon: "k.square", section: .discover,
        platform: "kakao",
        children: [
            SidebarItem(id: "kakao-recommend", title: "추천", icon: "star",
                        section: .discover, platform: "kakao", category: "recommend"),
            SidebarItem(id: "kakao-week", title: "요일별", icon: "calendar",
                        section: .discover, children: kakaoWeekdays),
            SidebarItem(id: "kakao-genre", title: "장르별", icon: "tag",
                        section: .discover, children: kakaoGenres),
            SidebarItem(id: "kakao-ranking", title: "실시간 랭킹", icon: "clock",
                        section: .discover, platform: "kakao", category: "ranking"),
            SidebarItem(id: "kakao-new", title: "신작", icon: "sparkles",
                        section: .discover, platform: "kakao", category: "new"),
            SidebarItem(id: "kakao-finished", title: "완결", icon: "checkmark.seal",
                        section: .discover, platform: "kakao", category: "finished"),
        ]
    )

    static let all: [SidebarItem] = [
        SidebarItem(id: "all", title: "전체보기", icon: "square.grid.2x2", section: .discover),
        naver,
        kakao,
        SidebarItem(id: "library", title: "내 보관함", icon: "books.vertical.fill", section: .library),
        SidebarItem(id: "recent", title: "최근 본", icon: "clock.arrow.circlepath", section: .library),
    ]
}
