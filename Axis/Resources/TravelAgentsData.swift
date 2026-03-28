import Foundation

// MARK: - Travel Agent Model

struct TravelAgent: Identifiable, Codable {
    let id: UUID
    let agencyName: String
    let ownerName: String?
    let phone: String?
    let email: String?
    let city: String
    let state: String
    let website: String
    let services: [TravelService]
    let specialties: String?
    let description: String

    init(
        agencyName: String,
        ownerName: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        city: String,
        state: String,
        website: String,
        services: [TravelService],
        specialties: String? = nil,
        description: String
    ) {
        self.id = UUID()
        self.agencyName = agencyName
        self.ownerName = ownerName
        self.phone = phone
        self.email = email
        self.city = city
        self.state = state
        self.website = website
        self.services = services
        self.specialties = specialties
        self.description = description
    }
}

// MARK: - Travel Service Categories

enum TravelService: String, Codable, CaseIterable, Identifiable {
    case luxury = "Luxury"
    case budget = "Budget"
    case cruises = "Cruises"
    case group = "Group Travel"
    case corporate = "Corporate/Business"
    case honeymoon = "Honeymoon/Romance"
    case adventure = "Adventure"
    case family = "Family"
    case allInclusive = "All-Inclusive"
    case destinationWeddings = "Destination Weddings"
    case safari = "Safari"
    case cultural = "Cultural Tours"
    case solo = "Solo Travel"
    case wellness = "Wellness/Spa"
    case skiAndSnow = "Ski & Snow"
    case river = "River Cruises"
    case ocean = "Ocean Cruises"
    case expedition = "Expedition Cruises"
    case escorted = "Escorted Tours"
    case custom = "Custom/Bespoke"
    case vip = "VIP Concierge"
    case active = "Active/Biking/Hiking"
    case heritage = "Heritage/Diaspora"
    case youth = "Youth/Young Adult"
    case senior = "Senior Travel"
    case roadTrip = "Road Trips"

    var id: String { rawValue }
}

// MARK: - Travel Agent Data

struct TravelAgentsData {

    static let allAgents: [TravelAgent] = [

        // ===================================================================
        // MARK: - LUXURY TRAVEL AGENCIES
        // ===================================================================

        TravelAgent(
            agencyName: "Protravel International",
            phone: "(212) 755-4550",
            city: "New York",
            state: "NY",
            website: "https://www.protravelinc.com",
            services: [.luxury, .cruises, .honeymoon, .corporate, .vip, .custom],
            specialties: "Virtuoso top US agency producer for 15 consecutive years; Travel + Leisure A-List",
            description: "With over 35 years of experience and 24 branch locations, Protravel International is a premier full-service luxury travel agency serving high-net-worth individuals. They offer VIP concierge services, air, hotel, cruise, and ground transportation planning."
        ),

        TravelAgent(
            agencyName: "SmartFlyer",
            ownerName: "Michael Holtz",
            phone: "(212) 268-9088",
            city: "New York",
            state: "NY",
            website: "https://smartflyer.com",
            services: [.luxury, .corporate, .custom, .honeymoon, .family],
            specialties: "Largest representation of Conde Nast Top Travel Specialists 2025 (44 advisors)",
            description: "Founded in 1990 by Michael Holtz, SmartFlyer is a full-service luxury travel agency catering to corporate and leisure travelers. Recognized as an Inc. Best in Business company, they are a Virtuoso member with headquarters in NYC and offices worldwide."
        ),

        TravelAgent(
            agencyName: "Embark Beyond",
            ownerName: "Jack Ezon",
            phone: "(212) 542-4500",
            city: "New York",
            state: "NY",
            website: "https://embarkbeyond.com",
            services: [.luxury, .custom, .honeymoon, .family, .vip],
            specialties: "Modern luxury approach with strong hotel relationships; Travel Weekly Power List",
            description: "Led by Managing Partner/CEO Jack Ezon, Embark Beyond is a New York City-based luxury travel agency known for bespoke travel experiences, exclusive hotel perks, and private celebrations for high-end clients."
        ),

        TravelAgent(
            agencyName: "Scott Dunn",
            phone: "(858) 523-9000",
            city: "Solana Beach",
            state: "CA",
            website: "https://www.scottdunn.com/us",
            services: [.luxury, .family, .safari, .skiAndSnow, .honeymoon, .custom],
            specialties: "Conde Nast Best Travel Specialist in the World for 13 consecutive years",
            description: "An award-winning luxury travel company curating journeys since 1986. Scott Dunn specializes in family holidays, ski trips, private villa rentals, and safaris, with 24/7 support and offices in Solana Beach, CA and New York City."
        ),

        TravelAgent(
            agencyName: "Black Tomato",
            phone: "(646) 558-3644",
            city: "New York",
            state: "NY",
            website: "https://www.blacktomato.com/us",
            services: [.luxury, .adventure, .custom, .honeymoon],
            specialties: "Known for innovative 'Get Lost' mystery trips and experiential travel",
            description: "For over 20 years, Black Tomato has been recognized as one of the world's leading luxury travel planners. They specialize in bespoke journeys, experiential travel, and off-the-beaten-path adventures with a focus on innovation."
        ),

        TravelAgent(
            agencyName: "Abercrombie & Kent",
            phone: "(800) 554-7016",
            city: "Downers Grove",
            state: "IL",
            website: "https://www.abercrombiekent.com",
            services: [.luxury, .safari, .cruises, .expedition, .group, .custom, .family],
            specialties: "Pioneer of luxury small-group travel; 60+ years; 50+ offices in 30+ countries",
            description: "Founded in 1962, Abercrombie & Kent pioneered the concept of luxury small-group travel and continues to lead with journeys to more than 100 countries. They offer luxury safaris, private jet expeditions, expedition cruises, and custom trips."
        ),

        TravelAgent(
            agencyName: "Ker & Downey",
            phone: "(800) 423-4236",
            email: "luxury@kerdowney.com",
            city: "Houston",
            state: "TX",
            website: "https://kerdowney.com",
            services: [.luxury, .safari, .adventure, .custom, .honeymoon, .family],
            specialties: "Conde Nast Traveler Top Travel Specialists 2025; experiential luxury",
            description: "Ker & Downey is a luxury experiential travel company based in Texas specializing in bespoke trips to every corner of the globe. Four of their designers were named Conde Nast Traveler Top Travel Specialists in 2025."
        ),

        TravelAgent(
            agencyName: "Micato Safaris",
            phone: "(800) 642-2861",
            email: "inquiries@micato.com",
            city: "New York",
            state: "NY",
            website: "https://www.micato.com",
            services: [.luxury, .safari, .custom],
            specialties: "Ultra-luxury African safaris; 'One for One' philanthropic program; 50+ years",
            description: "Micato Safaris has been crafting ultra-luxury African safari experiences for over 50 years. Based in New York, they offer private air charters and deeply personal safari itineraries, complemented by their One for One philanthropic giving program."
        ),

        TravelAgent(
            agencyName: "Kensington Tours",
            phone: "(866) 445-8487",
            city: "Toronto",
            state: "ON",
            website: "https://www.kensingtontours.com",
            services: [.luxury, .custom, .family, .adventure, .safari, .cultural],
            specialties: "100% custom private-guided trips to 100+ countries",
            description: "Kensington Tours specializes in completely customized private-guided trips to over 100 countries. Every trip features personal guides, private transfers, and dedicated destination experts for a truly bespoke travel experience."
        ),

        TravelAgent(
            agencyName: "Zicasso",
            phone: "(888) 441-2418",
            city: "Mountain View",
            state: "CA",
            website: "https://www.zicasso.com",
            services: [.luxury, .custom, .safari, .honeymoon, .family, .adventure],
            specialties: "Most-reviewed and highest-rated luxury travel company",
            description: "Established in 2008, Zicasso is the most-reviewed and highest-rated luxury travel company, connecting travelers with top specialist agencies for immersive custom tours, vacations, and safaris in over 100 countries."
        ),

        TravelAgent(
            agencyName: "The Luxury Travel Agency",
            phone: "(615) 955-5525",
            city: "Nashville",
            state: "TN",
            website: "https://www.theluxurytravelagency.com",
            services: [.luxury, .honeymoon, .family, .custom, .vip],
            description: "A premier luxury travel agency based in Nashville offering personalized high-end travel experiences including honeymoons, family vacations, and VIP concierge services with curated itineraries worldwide."
        ),

        TravelAgent(
            agencyName: "58 Stars",
            phone: "(425) 483-8687",
            city: "Seattle",
            state: "WA",
            website: "https://www.58starstravel.com",
            services: [.luxury, .custom, .vip, .honeymoon, .family],
            description: "58 Stars is a luxury travel agency specializing in tailored, seamless, custom travel with insider-style itineraries. They create personalized concierge-level experiences for discerning travelers."
        ),

        TravelAgent(
            agencyName: "Butterfield & Robinson",
            phone: "(800) 678-1147",
            email: "info@butterfield.com",
            city: "Toronto",
            state: "ON",
            website: "https://www.butterfield.com",
            services: [.luxury, .active, .custom, .cultural],
            specialties: "Pioneer of luxury active travel since 1966; biking and walking tours",
            description: "Since 1966, Butterfield & Robinson has pioneered luxury active travel with world-class biking and walking tours. They offer gourmet dining experiences, private active journeys, and bespoke trips in the world's most captivating destinations."
        ),

        TravelAgent(
            agencyName: "Valerie Wilson Travel",
            phone: "(212) 532-3400",
            city: "New York",
            state: "NY",
            website: "https://www.valeriewilsontravel.com",
            services: [.luxury, .corporate, .cruises, .custom, .family, .honeymoon],
            specialties: "Over 40 years of luxury travel; Virtuoso member; multiple US offices",
            description: "For over 40 years since 1981, Valerie Wilson Travel has been curating the world's finest travel experiences. A Virtuoso member with offices in New York, Connecticut, California, and South Carolina, they deliver unmatched luxury service."
        ),

        TravelAgent(
            agencyName: "FROSCH by Chase Travel",
            phone: "(866) 841-3555",
            email: "travelwithus@frosch.com",
            city: "Houston",
            state: "TX",
            website: "https://www.frosch.com",
            services: [.luxury, .corporate, .cruises, .custom, .vip],
            specialties: "Travel Weekly Power List; 24/7 availability; Chase Travel partnership",
            description: "FROSCH is a top-ranked luxury and corporate travel agency headquartered in Houston. With 24/7 availability and a partnership with Chase Travel, they provide premium travel planning for both leisure and business clients."
        ),

        TravelAgent(
            agencyName: "Fora Travel",
            phone: "(844) 409-3672",
            city: "New York",
            state: "NY",
            website: "https://www.foratravel.com",
            services: [.luxury, .honeymoon, .adventure, .family, .custom],
            specialties: "24 advisors named to Conde Nast Travel Specialists 2025 list",
            description: "Fora Travel is a modern travel agency headquartered in lower Manhattan with a network of expert advisors specializing in everything from sports travel and African safaris to luxe Caribbean escapes and family-friendly destinations."
        ),

        TravelAgent(
            agencyName: "All Roads North",
            ownerName: "Sam Highley",
            phone: "(310) 402-2031",
            city: "Venice",
            state: "CA",
            website: "https://www.allroadsnorth.com",
            services: [.luxury, .roadTrip, .custom, .adventure],
            specialties: "Conde Nast Top Travel Specialist 5 years running (2020-2025)",
            description: "Founded by Sam Highley, All Roads North specializes in meticulously tailor-made luxury American road trips. Each journey guide is bespoke, designed to fit unique interests. Sam has been named a Conde Nast Top Travel Specialist for five consecutive years."
        ),

        TravelAgent(
            agencyName: "Arbiter Travel Co.",
            phone: "(818) 505-3150",
            email: "contact@arbitertravel.com",
            city: "Los Angeles",
            state: "CA",
            website: "https://arbitertravel.com",
            services: [.luxury, .custom, .honeymoon, .adventure],
            specialties: "Conde Nast Traveler Top Travel Specialists 2025",
            description: "Arbiter Travel Co. is a boutique luxury travel agency in Los Angeles specializing in custom travel planning for high-end clients. Named to Conde Nast Traveler's Top Travel Specialists list."
        ),

        TravelAgent(
            agencyName: "Gifted Travel Network",
            phone: "(704) 585-7732",
            email: "info@giftedtravelnetwork.com",
            city: "Mooresville",
            state: "NC",
            website: "https://www.giftedtravelnetwork.com",
            services: [.luxury, .custom, .honeymoon, .family, .cruises],
            specialties: "Travel Weekly Power List 2025; host agency for luxury travel advisors",
            description: "Gifted Travel Network is a premier host agency for luxury travel advisors, based in Mooresville, North Carolina. Named to the Travel Weekly Power List, they have had 11+ advisors recognized as Conde Nast Top Travel Specialists."
        ),

        TravelAgent(
            agencyName: "Departure Lounge",
            phone: "(512) 322-9399",
            email: "info@departurelounge.com",
            city: "West Lake Hills",
            state: "TX",
            website: "https://departurelounge.com",
            services: [.luxury, .custom, .honeymoon, .family, .adventure],
            specialties: "Virtuoso member; global upscale luxury travel agency",
            description: "Departure Lounge is a global upscale luxury travel agency based in Austin, Texas, designed to beautifully inspire and curate travel to the best places on earth. They serve clients nationwide as a Virtuoso member host travel agency."
        ),

        TravelAgent(
            agencyName: "Coastline Travel Advisors",
            phone: "(714) 621-1040",
            email: "info@coastlinetravel.com",
            city: "Garden Grove",
            state: "CA",
            website: "https://www.coastlinetravel.com",
            services: [.luxury, .corporate, .adventure, .group, .family, .custom],
            specialties: "Travel Weekly Power List 2025; 30+ years in the industry; Virtuoso member",
            description: "With over 30 years in the travel industry, Coastline Travel Advisors stands out as an industry leader on the Travel Weekly Power List. They specialize in luxury, adventure, corporate, group, and family travel."
        ),

        TravelAgent(
            agencyName: "Luxury Travel Curators",
            phone: "(917) 754-5515",
            city: "Miami",
            state: "FL",
            website: "https://www.luxurytravelcurators.com",
            services: [.luxury, .custom, .honeymoon, .cultural],
            specialties: "Conde Nast Traveler Top Travel Specialist 2025",
            description: "Luxury Travel Curators is a Miami-based boutique agency that customizes bespoke luxury travel experiences. They offer complimentary 15-minute consultations and curate authentic travel across the world."
        ),

        TravelAgent(
            agencyName: "Pavlus Travel",
            phone: "(800) 528-9300",
            city: "Albuquerque",
            state: "NM",
            website: "https://pavlus.com",
            services: [.luxury, .cruises, .river, .ocean, .escorted, .custom],
            specialties: "One of America's largest independent luxury travel companies",
            description: "Pavlus Travel is one of America's largest independent luxury travel companies, specializing in exclusive deals on Tauck, Viking, Regent, and other premium cruise and tour lines with personalized planning."
        ),

        // ===================================================================
        // MARK: - HONEYMOON & ROMANCE SPECIALISTS
        // ===================================================================

        TravelAgent(
            agencyName: "Unforgettable Honeymoons",
            ownerName: "Renee Meyer",
            phone: "(888) 343-6413",
            email: "info@unforgettablehoneymoons.com",
            city: "Portland",
            state: "OR",
            website: "https://www.unforgettablehoneymoons.com",
            services: [.honeymoon, .destinationWeddings, .allInclusive, .luxury],
            specialties: "Nation's leading honeymoon travel agency since 1994; 10,000+ honeymoons planned",
            description: "Founded by Renee Meyer in 1994, Unforgettable Honeymoons is the nation's leading honeymoon niche travel agency with over 10,000 honeymoons designed and planned. Based in Portland, Oregon with expert advisors."
        ),

        TravelAgent(
            agencyName: "Romantics Travel",
            ownerName: "Jeff & Kimberly Jacoby",
            phone: "(817) 386-0701",
            city: "Fort Worth",
            state: "TX",
            website: "https://www.romanticstravel.com",
            services: [.honeymoon, .destinationWeddings, .allInclusive, .luxury],
            specialties: "Award-winning; featured in Brides Magazine; 5/5 rating with 107 reviews",
            description: "Owned by husband-and-wife team Jeff and Kimberly Jacoby, Romantics Travel is a boutique, highly specialized luxury agency in Fort Worth. With 18+ years of experience, they specialize in Mexico and Caribbean all-inclusive destination weddings and honeymoons."
        ),

        TravelAgent(
            agencyName: "Over The Moon Vacations",
            phone: "(305) 741-6194",
            city: "Miami",
            state: "FL",
            website: "https://www.overthemoonvacations.com",
            services: [.honeymoon, .luxury, .allInclusive, .destinationWeddings],
            description: "Over The Moon Vacations is a Miami-based luxury honeymoon and travel planning agency offering curated romantic getaway packages, destination wedding coordination, and all-inclusive resort experiences."
        ),

        TravelAgent(
            agencyName: "WeddingVibe / VibeGetaways",
            phone: "(262) 891-4768",
            city: "Mays Landing",
            state: "NJ",
            website: "https://weddingvibe.com",
            services: [.honeymoon, .destinationWeddings, .allInclusive],
            specialties: "Awarded #1 Sandals Travel Agency in the USA two years in a row",
            description: "WeddingVibe (operating as VibeGetaways) is the #1 Sandals and Beaches travel agency in the USA. They specialize in all-inclusive Caribbean honeymoons, destination weddings, and romantic getaways at Sandals and Beaches Resorts."
        ),

        TravelAgent(
            agencyName: "Beach Bum Vacations",
            phone: "(877) 943-8282",
            email: "sales@beachbumvacation.com",
            city: "Mays Landing",
            state: "NJ",
            website: "https://www.beachbumvacation.com",
            services: [.honeymoon, .destinationWeddings, .family, .allInclusive, .group],
            specialties: "Award-winning family vacation and honeymoon travel agents",
            description: "Beach Bum Vacations is an award-winning luxury travel concierge specializing in all-inclusive beach vacations, family travel, honeymoons, and destination weddings. They operate nationwide with personalized service."
        ),

        TravelAgent(
            agencyName: "The Concierge Travel Group",
            city: "Hoboken",
            state: "NJ",
            website: "https://theconciergetravelgroup.com",
            services: [.honeymoon, .luxury, .custom, .destinationWeddings],
            specialties: "Experts in luxury honeymoon design for over a decade",
            description: "The Concierge Travel Group is a boutique travel agency in Hoboken, NJ that combines superior client care with a tech-savvy approach to trip design. They specialize in honeymoons and luxury travel planning."
        ),

        // ===================================================================
        // MARK: - ADVENTURE TRAVEL AGENCIES
        // ===================================================================

        TravelAgent(
            agencyName: "Intrepid Travel",
            phone: "(800) 970-7299",
            city: "New York",
            state: "NY",
            website: "https://www.intrepidtravel.com/us",
            services: [.adventure, .group, .cultural, .family, .solo],
            specialties: "Specialized in small group adventures since 1989; 24/7 call center",
            description: "Intrepid Travel has specialized in real, rare, and remarkable small group adventures since 1989. With a US office in New York and 24/7 support, they offer responsible travel experiences across the globe."
        ),

        TravelAgent(
            agencyName: "Exodus Adventure Travels",
            phone: "(844) 227-9087",
            email: "usa@exodustravels.com",
            city: "Seattle",
            state: "WA",
            website: "https://www.exodustravels.com/us",
            services: [.adventure, .active, .group, .cultural, .solo],
            specialties: "National Geographic Best Tour Operator Award winner; original adventure travel company",
            description: "Exodus Adventure Travels is the overall winner of National Geographic's Best Tour Operator Award and the original activity and adventure travel company. Their US office is in Seattle with adventure tours worldwide."
        ),

        TravelAgent(
            agencyName: "Overseas Adventure Travel (O.A.T.)",
            phone: "(800) 955-1925",
            city: "Boston",
            state: "MA",
            website: "https://www.oattravel.com",
            services: [.adventure, .group, .cruises, .expedition, .cultural, .senior],
            specialties: "Leader in small group travel and small ship adventures; all seven continents",
            description: "Part of the Grand Circle family, O.A.T. is the leader in small group adventure travel and small ship adventures on all seven continents. Based in Boston, they serve travelers seeking authentic cultural experiences."
        ),

        TravelAgent(
            agencyName: "Backroads",
            phone: "(800) 462-2848",
            email: "backroadsguestservices@backroads.com",
            city: "Berkeley",
            state: "CA",
            website: "https://www.backroads.com",
            services: [.adventure, .active, .luxury, .family],
            specialties: "Premier active travel: biking, hiking, walking, multisport trips",
            description: "Backroads is the world's premier active travel company based in Berkeley, California, offering biking, walking, hiking, and multisport trips. They feature three family-focused trip categories by age group."
        ),

        TravelAgent(
            agencyName: "Wilderness Travel",
            phone: "(800) 368-2794",
            email: "info@wildernesstravel.com",
            city: "Berkeley",
            state: "CA",
            website: "https://www.wildernesstravel.com",
            services: [.adventure, .cultural, .active, .safari, .group],
            specialties: "Award-winning adventure tours since 1978",
            description: "Wilderness Travel is an award-winning adventure travel company in Berkeley, California, offering guided tours worldwide including trekking, cultural journeys, wildlife safaris, and active adventures since 1978."
        ),

        TravelAgent(
            agencyName: "AdventureSmith Explorations",
            ownerName: "Todd Smith",
            phone: "(877) 620-2875",
            city: "Truckee",
            state: "CA",
            website: "https://adventuresmithexplorations.com",
            services: [.adventure, .expedition, .cruises, .family, .group],
            specialties: "Global leader in small ship adventure cruises; Conde Nast Top Travel Specialist 12 years",
            description: "AdventureSmith Explorations is the global leader in small ship adventure cruises. Founded by Todd Smith, who has been a Conde Nast Top Travel Specialist for 12 consecutive years, they offer personalized travel planning."
        ),

        TravelAgent(
            agencyName: "Asia Transpacific Journeys (ATJ)",
            phone: "(800) 642-2742",
            email: "info@atj.com",
            city: "Boulder",
            state: "CO",
            website: "https://www.atj.com",
            services: [.luxury, .adventure, .cultural, .custom],
            specialties: "Conde Nast Top Travel Specialist 2025; luxury Asia and Pacific travel",
            description: "ATJ specializes in luxury custom and private-guided tours to Asia, the Pacific, and beyond. Based in Boulder, Colorado, they are a Conde Nast Top Travel Specialist offering deeply immersive cultural experiences."
        ),

        // ===================================================================
        // MARK: - FAMILY TRAVEL SPECIALISTS
        // ===================================================================

        TravelAgent(
            agencyName: "Ciao Bambino",
            city: "Piedmont",
            state: "CA",
            website: "https://ciaobambino.com",
            services: [.family, .luxury, .custom],
            specialties: "Award-winning family travel experts for two decades; Virtuoso member",
            description: "Ciao Bambino is a global, award-winning full-service travel agency specializing in luxury family vacations. For two decades, their advisors have helped families plan dream vacations with exclusive perks at top-tier properties."
        ),

        TravelAgent(
            agencyName: "Adventures by Disney",
            phone: "(800) 543-0865",
            city: "Anaheim",
            state: "CA",
            website: "https://www.adventuresbydisney.com",
            services: [.family, .group, .adventure, .cultural, .escorted],
            specialties: "50+ itineraries in 40+ countries; guided trips with Disney storytelling",
            description: "Adventures by Disney offers upscale small group tours with 50+ itineraries in over 40 countries. They feature hands-on local experiences, expert guides, and built-in time for families to enjoy together and apart."
        ),

        TravelAgent(
            agencyName: "Thomson Family Adventures",
            phone: "(800) 262-6255",
            email: "info@familyadventures.com",
            city: "Watertown",
            state: "MA",
            website: "https://familyadventures.com",
            services: [.family, .adventure, .cultural, .group],
            specialties: "Friends Across Borders pen pal program; international family adventure",
            description: "Thomson Family Adventures creates meaningful connections through travel, including their Friends Across Borders pen pal initiative. Based in Watertown, MA, they specialize in international adventure travel for families."
        ),

        TravelAgent(
            agencyName: "Vacationkids",
            phone: "(610) 681-7360",
            city: "Kunkletown",
            state: "PA",
            website: "https://www.vacationkids.com",
            services: [.family, .allInclusive, .cruises, .adventure, .budget],
            specialties: "Certified family travel advisors; complimentary consultations",
            description: "Vacationkids has certified family travel advisors who help busy parents plan and book affordable family resorts, cruises, tours, and adventure packages to any destination worldwide. They offer free 15-20 minute consultations."
        ),

        // ===================================================================
        // MARK: - GROUP TRAVEL SPECIALISTS
        // ===================================================================

        TravelAgent(
            agencyName: "Odysseys Unlimited",
            phone: "(888) 370-6765",
            email: "travel@odysseys-unlimited.com",
            city: "Newton",
            state: "MA",
            website: "https://www.odysseys-unlimited.com",
            services: [.group, .escorted, .cultural, .luxury],
            specialties: "7x Travel + Leisure World's Best; #2 Best Group Tour Company USA Today",
            description: "A seven-time honoree of Travel + Leisure World's Best Tour Operators and ranked #2 Best Group Tour Company by USA Today. Based in Newton, MA, Odysseys Unlimited specializes in small group travel worldwide."
        ),

        TravelAgent(
            agencyName: "Collette",
            phone: "(800) 468-5955",
            city: "Pawtucket",
            state: "RI",
            website: "https://www.gocollette.com",
            services: [.group, .escorted, .cultural, .adventure, .river],
            specialties: "100+ years of expertise; 40+ US tours; guided tours worldwide",
            description: "With over 100 years of expertise, Collette offers guided travel tours across all seven continents including 40+ US tours. Based in Pawtucket, Rhode Island, they provide expertly crafted group travel experiences."
        ),

        TravelAgent(
            agencyName: "EF Go Ahead Tours",
            phone: "(800) 590-1161",
            city: "Cambridge",
            state: "MA",
            website: "https://www.goaheadtours.com",
            services: [.group, .escorted, .cultural, .adventure, .budget],
            specialties: "200+ immersive guided tours worldwide; affordable group travel",
            description: "EF Go Ahead Tours offers 200+ immersive, guided tours around the world. Based in Cambridge, MA with extensive support hours, they make guided group travel accessible and enriching for all travelers."
        ),

        TravelAgent(
            agencyName: "Contiki",
            phone: "(866) 266-8454",
            city: "Costa Mesa",
            state: "CA",
            website: "https://www.contiki.com/en-us",
            services: [.group, .adventure, .youth, .cultural, .budget],
            specialties: "200+ trips exclusively for travelers ages 18-35",
            description: "Contiki offers 200+ trips exclusively for 18-35 year olds, led by expert group travel guides. Based in Costa Mesa, CA with 24/7 support, they specialize in social, adventure-focused group experiences for young adults."
        ),

        TravelAgent(
            agencyName: "Tauck",
            phone: "(800) 788-7885",
            city: "Norwalk",
            state: "CT",
            website: "https://www.tauck.com",
            services: [.group, .luxury, .family, .cruises, .river, .escorted],
            specialties: "Premium all-inclusive guided tours and river cruises since 1925",
            description: "Since 1925, Tauck has been a family-owned tour company offering premium all-inclusive guided tours, river cruises, and family travel experiences worldwide. Based in Norwalk, Connecticut with exceptional quality standards."
        ),

        // ===================================================================
        // MARK: - CRUISE SPECIALISTS
        // ===================================================================

        TravelAgent(
            agencyName: "Luxury Cruise Connections",
            phone: "(866) 997-0377",
            city: "Miami",
            state: "FL",
            website: "https://luxurycruiseconnections.com",
            services: [.cruises, .luxury, .ocean, .river, .expedition],
            specialties: "North America's Best Cruise Travel Agency 4 years running (World Cruise Awards)",
            description: "Named North America's Best Cruise Travel Agency by the World Cruise Awards for four consecutive years, Luxury Cruise Connections is a Virtuoso agency in Miami specializing in luxury ocean, river, and expedition cruises."
        ),

        TravelAgent(
            agencyName: "Cruise Specialists",
            phone: "(800) 544-2469",
            email: "mail@cruisespecialists.com",
            city: "Seattle",
            state: "WA",
            website: "https://www.cruisespecialists.com",
            services: [.cruises, .luxury, .ocean, .river, .expedition],
            specialties: "Experts in Crystal, Regent Seven Seas, and Seabourn luxury cruises",
            description: "Cruise Specialists is known for expertise in the luxury cruise segment. Based in Seattle, they are specialists in premium lines like Crystal, Regent Seven Seas Cruises, and Seabourn, with extensive knowledge of world cruises."
        ),

        TravelAgent(
            agencyName: "CruisesOnly",
            phone: "(800) 278-4737",
            city: "Fort Lauderdale",
            state: "FL",
            website: "https://www.cruisesonly.com",
            services: [.cruises, .ocean, .river, .budget, .family, .group],
            specialties: "Award-winning service; widest cruise selection; 40+ years of expertise",
            description: "CruisesOnly has offered award-winning cruise booking service for over 40 years with the widest cruise selection and unparalleled expertise. They provide cruises for every budget from value to ultra-luxury."
        ),

        TravelAgent(
            agencyName: "Cruise Planners",
            phone: "(954) 344-8060",
            city: "Coral Springs",
            state: "FL",
            website: "https://www.cruiseplanners.com",
            services: [.cruises, .allInclusive, .destinationWeddings, .group, .family],
            specialties: "Founded 1994; cruise, land tour, and group travel specialists",
            description: "Founded in 1994, Cruise Planners is headquartered in Coral Springs, Florida. They specialize in cruises, custom vacation packages, land tours, and excel at group travel and destination weddings."
        ),

        TravelAgent(
            agencyName: "Cruise Brothers",
            phone: "(800) 827-7779",
            email: "sales@cruisebrothers.com",
            city: "Warwick",
            state: "RI",
            website: "https://www.cruisebrothers.com",
            services: [.cruises, .luxury, .family, .group],
            specialties: "Family-owned since 1972; one of America's largest cruise agencies",
            description: "Cruise Brothers is one of the largest family-owned cruise agencies in the country, booking cruise vacations since 1972. Based in Warwick, Rhode Island, they offer personalized service for luxury and family cruises."
        ),

        TravelAgent(
            agencyName: "CruiseDirect",
            phone: "(888) 407-2784",
            email: "support@cruisedirect.com",
            city: "Morristown",
            state: "NJ",
            website: "https://www.cruisedirect.com",
            services: [.cruises, .ocean, .budget],
            specialties: "No booking fees; best price guarantee; online cruise reservations",
            description: "CruiseDirect is a New Jersey-based online cruise booking agency with no booking fees and a best price guarantee. They make cruise booking simple and affordable with competitive pricing across all major cruise lines."
        ),

        // ===================================================================
        // MARK: - BLACK-OWNED TRAVEL AGENCIES
        // ===================================================================

        TravelAgent(
            agencyName: "Travel Divas",
            phone: "(770) 232-6483",
            city: "Atlanta",
            state: "GA",
            website: "https://thetraveldivas.com",
            services: [.group, .luxury, .adventure, .cultural, .heritage],
            specialties: "Award-winning; 100+ curated group experiences per year since 2007",
            description: "Travel Divas is an award-winning Black-owned travel company that has been redefining how women experience the world since 2007. They specialize in upscale group travel for Black women with 100+ expertly curated experiences annually."
        ),

        TravelAgent(
            agencyName: "Up in the Air Life",
            ownerName: "Claire Soares",
            city: "Atlanta",
            state: "GA",
            website: "https://upintheairlife.com",
            services: [.luxury, .group, .adventure, .heritage, .cultural],
            specialties: "5x Conde Nast Top Travel Specialist; multimillion-dollar travel empire",
            description: "Founded by CEO Claire Soares, a 5x Conde Nast Top Travel Specialist, Up in the Air Life is a boutique luxury travel agency empowering Black travelers to experience the finer things in life with confidence."
        ),

        TravelAgent(
            agencyName: "Jelani Travel",
            ownerName: "Ashley N. Company",
            city: "Washington",
            state: "DC",
            website: "https://gojelanitravel.com",
            services: [.heritage, .cultural, .group, .adventure, .custom],
            specialties: "10+ years; 600+ global travel experiences to 108 countries; Africa specialists",
            description: "Jelani Travel is a Black woman-owned company in Washington, D.C., helping people of African descent reimagine Africa. Founded by Ashley N. Company, they have curated 600+ travel experiences across 108 countries over the past decade."
        ),

        TravelAgent(
            agencyName: "Nomadness Travel Tribe",
            ownerName: "Evita Robinson",
            phone: "(845) 590-9248",
            city: "New York",
            state: "NY",
            website: "https://nomadnesstraveltribe.com",
            services: [.group, .adventure, .cultural, .heritage, .solo],
            specialties: "Pioneer of BIPOC urban travel movement; 30,000+ members; $50M+ travel spending",
            description: "Founded by Emmy award-winning Evita 'Evie' Robinson in 2011, Nomadness Travel Tribe is a community of over 30,000 Black and Brown nomads responsible for $50M+ injected into the travel industry annually."
        ),

        TravelAgent(
            agencyName: "Henderson Travel Service",
            ownerName: "Dr. Gaynelle Henderson",
            city: "Washington",
            state: "DC",
            website: "https://hendersontravel.com",
            services: [.heritage, .cultural, .group, .safari],
            specialties: "First Black-owned travel agency in the US, founded 1955; Africa travel pioneers",
            description: "Founded by Freddye and Jacob Henderson in Atlanta in 1955, Henderson Travel Service is the first and oldest Black-owned travel agency in America. Now run by Dr. Gaynelle Henderson, they pioneered travel to Africa and planned trips for Martin Luther King Jr.'s family."
        ),

        TravelAgent(
            agencyName: "Travel with Sparkle",
            ownerName: "Nadia 'Sparkle' Henry",
            phone: "(201) 688-7478",
            email: "info@travelwithsparkle.com",
            city: "West Orange",
            state: "NJ",
            website: "https://www.travelwithsparkle.com",
            services: [.luxury, .group, .heritage, .cultural, .solo],
            specialties: "Award-winning lifestyle travel agency; Travel Weekly columnist",
            description: "Founded in 2007 by Nadia 'Sparkle' Henry, Travel with Sparkle is an award-winning lifestyle travel agency specializing in luxury and international group travel. Nadia is also a Travel Weekly columnist."
        ),

        TravelAgent(
            agencyName: "BWP Travel",
            ownerName: "Bruce Powell",
            city: "Atlanta",
            state: "GA",
            website: "https://bwptravel.com",
            services: [.luxury, .custom, .heritage, .cultural, .honeymoon],
            specialties: "Virtuoso affiliated agency; full-service luxury travel",
            description: "Led by Bruce Powell with over a decade of experience, BWP Travel is a full-service Virtuoso-affiliated luxury travel agency in Atlanta. They specialize in tailoring experiences for all types of travelers nationwide."
        ),

        TravelAgent(
            agencyName: "LaVon Private Luxury",
            ownerName: "Tiffany LaVon Layne",
            phone: "(646) 598-6933",
            city: "New York",
            state: "NY",
            website: "https://www.lavonprivateluxury.com",
            services: [.luxury, .custom, .heritage, .corporate],
            specialties: "Bespoke luxury services for jet-setters and business travelers",
            description: "Founded in 2017 by Tiffany LaVon Layne, a former biomedical scientist, LaVon Private Luxury provides uniquely bespoke travel services to sophisticated leisure jet-setters and discerning business travelers."
        ),

        TravelAgent(
            agencyName: "Passport Poppin",
            phone: "(315) 802-5090",
            email: "letsgo@passportpoppin.com",
            city: "Washington",
            state: "DC",
            website: "https://www.passportpoppin.com",
            services: [.luxury, .group, .heritage, .custom, .adventure],
            specialties: "Black Woman-Owned; full-service since 2019; hosted group trips year-round",
            description: "Passport Poppin is a Black Woman-Owned, full-service travel agency providing perfectly planned luxury travel experiences since 2019. They offer personalized planning and hosted group trips year-round."
        ),

        TravelAgent(
            agencyName: "Jet Set Black Travel",
            phone: "(757) 231-5505",
            city: "Virginia Beach",
            state: "VA",
            website: "https://www.jetsetblacktravelagency.com",
            services: [.luxury, .group, .heritage, .custom, .adventure],
            specialties: "Travel Planners International member; luxury experiences for Black travelers",
            description: "Jet Set Black Travel is a luxury travel agency in Virginia Beach, VA, providing exclusive access to high-end destinations and curated itineraries. A member of Travel Planners International with a focus on the Black travel community."
        ),

        // ===================================================================
        // MARK: - CORPORATE / BUSINESS TRAVEL
        // ===================================================================

        TravelAgent(
            agencyName: "Navan",
            phone: "(888) 505-8747",
            city: "Palo Alto",
            state: "CA",
            website: "https://navan.com",
            services: [.corporate],
            specialties: "G2 score 95/100 (#1 overall); AI-powered travel and expense management",
            description: "Navan is a top-ranked technology-driven corporate travel management solution in Palo Alto. They offer AI-powered personalized recommendations, dynamic travel policies, and integrated expense management with the highest industry ratings."
        ),

        TravelAgent(
            agencyName: "American Express Global Business Travel",
            phone: "(800) 444-5555",
            city: "Jersey City",
            state: "NJ",
            website: "https://www.amexglobalbusinesstravel.com",
            services: [.corporate, .group],
            specialties: "$30.48 billion in sales; Travel Weekly Power List #3",
            description: "American Express Global Business Travel is one of the biggest names in corporate travel, managing $30.48 billion in sales. They offer global travel booking, expense management, risk management, and meetings/events travel."
        ),

        TravelAgent(
            agencyName: "BCD Travel",
            phone: "(678) 441-5200",
            city: "Atlanta",
            state: "GA",
            website: "https://www.bcdtravel.com",
            services: [.corporate],
            specialties: "$22.9 billion in sales; 170+ countries; TripSource and BCD Pay tools",
            description: "BCD Travel is a privately held B2B travel management company reaching 170+ countries with $22.9 billion in sales. Based in Atlanta, they offer booking, consulting, sustainability, and risk management through proprietary tools."
        ),

        TravelAgent(
            agencyName: "Christopherson Business Travel",
            phone: "(801) 327-7700",
            city: "Salt Lake City",
            state: "UT",
            website: "https://www.cbtravel.com",
            services: [.corporate],
            specialties: "Operating since 1953; proprietary AirPortal platform for mid-size companies",
            description: "Based in Salt Lake City and operating since 1953, Christopherson Business Travel specializes in corporate travel management with their proprietary AirPortal platform. Ideal for mid-size companies wanting a hands-on TMC experience."
        ),

        TravelAgent(
            agencyName: "Corporate Traveler (Flight Centre)",
            phone: "(855) 246-2213",
            city: "Montvale",
            state: "NJ",
            website: "https://www.corporatetraveler.us",
            services: [.corporate],
            specialties: "Part of Flight Centre Travel Group ($15.91B sales); 24/7 support",
            description: "Corporate Traveler is Flight Centre Travel Group's dedicated corporate travel division. With $15.91 billion in total group sales, they offer dedicated Travel Managers, 24/7 support, and comprehensive business travel solutions."
        ),

        // ===================================================================
        // MARK: - BUDGET & VALUE TRAVEL
        // ===================================================================

        TravelAgent(
            agencyName: "Liberty Travel",
            phone: "(888) 634-7702",
            city: "Montvale",
            state: "NJ",
            website: "https://www.libertytravel.com",
            services: [.budget, .family, .honeymoon, .allInclusive, .group, .cruises],
            specialties: "65+ years of experience; nationwide retail locations",
            description: "With over 65 years of experience, Liberty Travel remains a staple in American travel with a focus on personalized service. Headquartered in Montvale, NJ, they are ideal for couples, families, and groups seeking value-oriented vacations."
        ),

        TravelAgent(
            agencyName: "AAA Travel",
            phone: "(800) 222-4357",
            city: "Nationwide",
            state: "US",
            website: "https://travel.aaa.com",
            services: [.budget, .family, .cruises, .allInclusive, .roadTrip],
            specialties: "Exclusive member discounts; trip planning tools; travel insurance",
            description: "Well-known for roadside assistance, AAA Travel also offers comprehensive trip planning tools, exclusive member discounts, and travel insurance. Their longevity and reliability make them a top choice for domestic and international travel."
        ),

        TravelAgent(
            agencyName: "Pack Up + Go",
            city: "Pittsburgh",
            state: "PA",
            website: "https://www.packupgo.com",
            services: [.budget, .adventure, .solo, .honeymoon],
            specialties: "America's #1 surprise travel agency; unique mystery destination concept",
            description: "Launched in Pittsburgh in 2016, Pack Up + Go is the United States' #1 surprise travel agency. Travelers fill out a questionnaire and budget, and the agency plans a complete trip to an unknown destination revealed only at departure."
        ),

        // ===================================================================
        // MARK: - FULL-SERVICE & NETWORK AGENCIES
        // ===================================================================

        TravelAgent(
            agencyName: "Travel Leaders",
            phone: "(763) 231-8440",
            city: "Minneapolis",
            state: "MN",
            website: "https://www.travelleaders.com",
            services: [.luxury, .corporate, .family, .cruises, .honeymoon, .group, .adventure],
            specialties: "#1 travel agent network in North America; 6,000+ agencies",
            description: "Travel Leaders operates as the #1 travel agent network in North America with over 6,000 agencies. They deliver custom experiences with national reach, with advisors specializing in everything from business trips to honeymoons."
        ),

        TravelAgent(
            agencyName: "Envoyage",
            city: "Nationwide",
            state: "US",
            website: "https://www.envoyage.com",
            services: [.luxury, .group, .cruises, .honeymoon, .destinationWeddings, .corporate, .family],
            specialties: "Named US Leading Travel Agency at 32nd World Travel Awards",
            description: "Envoyage has been named the United States' Leading Travel Agency at the 32nd annual World Travel Awards. They offer a nationwide network of travel advisors specializing in group travel, cruises, honeymoons, and destination weddings."
        ),

        TravelAgent(
            agencyName: "Elsewhere",
            city: "San Francisco",
            state: "CA",
            website: "https://www.elsewhere.io",
            services: [.luxury, .custom, .honeymoon, .adventure],
            specialties: "Membership-based luxury travel planning from $55/month",
            description: "Elsewhere is a modern luxury travel planning service offering personalized itinerary design, at-cost bookings, VIP hotel perks, and ongoing advisor support through a membership model starting at $55/month."
        ),

        TravelAgent(
            agencyName: "Luna Moons",
            city: "New York",
            state: "NY",
            website: "https://www.lunamoons.com",
            services: [.honeymoon, .luxury, .custom],
            description: "Luna is a modern honeymoon planning service that takes the stress out of honeymoon planning by pairing couples with expert advisors who curate personalized romantic getaways."
        ),

        TravelAgent(
            agencyName: "The Honeymoon Co.",
            city: "Nashville",
            state: "TN",
            website: "https://www.thehoneymooncompany.com",
            services: [.honeymoon, .destinationWeddings, .luxury, .allInclusive],
            description: "The Honeymoon Co. specializes in crafting unforgettable honeymoon experiences. Based in Nashville, they offer personalized romantic travel planning for couples seeking unique and memorable post-wedding getaways."
        ),

        TravelAgent(
            agencyName: "Remarkable Honeymoons",
            city: "Portland",
            state: "OR",
            website: "https://www.remarkablehoneymoons.com",
            services: [.honeymoon, .luxury, .allInclusive, .destinationWeddings],
            specialties: "Virtuoso affiliated; Hawaii, Tahiti, and Fiji specialists",
            description: "Remarkable Honeymoons is a Virtuoso-affiliated travel agency in Portland, Oregon, primarily focused on romantic itineraries with specialized expertise in Hawaii, Tahiti, Fiji, and other tropical honeymoon destinations."
        ),

        // ===================================================================
        // MARK: - ADDITIONAL NOTABLE AGENCIES
        // ===================================================================

        TravelAgent(
            agencyName: "Concierge Travel Inc.",
            ownerName: "Patricia Cooney",
            phone: "(610) 329-9044",
            city: "Philadelphia",
            state: "PA",
            website: "https://www.conciergetravelinc.com",
            services: [.luxury, .custom, .cruises, .honeymoon, .family],
            specialties: "Travel Leaders consortium member; personalized luxury service",
            description: "Led by Patricia Cooney, Concierge Travel Inc. is a Philadelphia-area luxury travel agency and Travel Leaders consortium member offering personalized cruise, honeymoon, and family vacation planning."
        ),

        TravelAgent(
            agencyName: "Luxury Travel Works",
            phone: "(615) 730-4456",
            city: "Nashville",
            state: "TN",
            website: "https://www.luxurytravelworks.com",
            services: [.luxury, .custom, .honeymoon, .family, .vip],
            description: "Luxury Travel Works is a Nashville-based luxury travel agency offering bespoke trip planning, honeymoons, family vacations, and VIP concierge services with a personal touch."
        ),

        TravelAgent(
            agencyName: "Nashville Luxury Travel",
            phone: "(615) 472-8432",
            city: "Brentwood",
            state: "TN",
            website: "https://nashvilleluxurytravel.com",
            services: [.luxury, .custom, .honeymoon, .family],
            specialties: "Virtuoso member agency in greater Nashville",
            description: "Nashville Luxury Travel is a Virtuoso member luxury travel agency in the greater Nashville area, offering curated high-end travel experiences with personalized service and exclusive perks."
        ),

        TravelAgent(
            agencyName: "Black Girls Travel Too (BGTT)",
            city: "Nationwide",
            state: "US",
            website: "https://www.blackgirlstraveltoo.com",
            services: [.group, .adventure, .heritage, .cultural, .solo],
            specialties: "International travel club empowering millennial Black women",
            description: "Black Girls Travel Too is an international travel club empowering millennial Black women through travel. They offer intimate group sizes allowing authentic local connections and meticulously planned itineraries."
        ),

        TravelAgent(
            agencyName: "En Root Travel",
            city: "Nationwide",
            state: "US",
            website: "https://www.enroottravel.com",
            services: [.group, .heritage, .cultural, .adventure],
            specialties: "Travel group specifically for HBCU alumni; African Diaspora destinations",
            description: "En Root Travel is a Black-owned travel group specifically for HBCU alumni, with trips exploring countries within the African Diaspora including Mexico, Colombia, Brazil, Ghana, and Dubai."
        ),

        TravelAgent(
            agencyName: "Maximum Impact Travel",
            ownerName: "Jay Cameron",
            city: "Nationwide",
            state: "US",
            website: "https://www.maximumimpacttravel.com",
            services: [.group, .heritage, .cultural, .adventure],
            specialties: "Africa-focused; connecting travelers of African descent",
            description: "Founded by CEO Jay Cameron, Maximum Impact Travel is focused on uniting those eager to explore Africa and deepen their connection to the African community through meaningful travel experiences."
        ),

        TravelAgent(
            agencyName: "Soulful Life Travel",
            city: "Nationwide",
            state: "US",
            website: "https://www.soulfullifetravel.com",
            services: [.heritage, .cultural, .adventure, .group, .custom],
            specialties: "Customized Afro-Caribbean heritage and culture experiences in Costa Rica",
            description: "Soulful Life Travel specializes in customized travel experiences emphasizing Afro-Caribbean heritage and culture in Costa Rica, providing ground transportation, hotel accommodation, select meals, and activities."
        ),

        TravelAgent(
            agencyName: "Two Oceans Travel and Tours",
            city: "Nationwide",
            state: "US",
            website: "https://www.twooceanstravelandtours.com",
            services: [.heritage, .cultural, .adventure, .budget, .group],
            specialties: "Affordable, unique itineraries; decade of experience",
            description: "With over a decade of experience, Two Oceans Travel and Tours creates affordable, unique, and memorable itineraries with a focus on cultural immersion and heritage travel."
        ),

        TravelAgent(
            agencyName: "Black In Travel",
            ownerName: "Nubia Younge",
            city: "Nationwide",
            state: "US",
            website: "https://www.blackintravel.com",
            services: [.heritage, .cultural, .adventure, .group, .solo],
            specialties: "Empowering travelers of color to explore with confidence",
            description: "Founded by Nubia Younge, Black In Travel is on a mission to empower travelers of color to explore the world with confidence and authenticity through curated travel experiences and community."
        ),

        TravelAgent(
            agencyName: "JetBlack Travel",
            city: "Nationwide",
            state: "US",
            website: "https://jetblacktravel.com",
            services: [.luxury, .group, .heritage, .adventure, .cultural],
            specialties: "Curated group trips to Africa, Caribbean, South America, and Asia",
            description: "JetBlack Travel is a luxury travel agency specializing in curated group trips of 8-15 participants to destinations including South Africa, Ghana, Senegal, Jamaica, Egypt, Brazil, Kenya, Zanzibar, and Bali."
        ),

        TravelAgent(
            agencyName: "Black Travel Worldwide",
            city: "Nationwide",
            state: "US",
            website: "https://www.blacktravelworldwide.com",
            services: [.group, .heritage, .cultural, .solo, .custom],
            specialties: "Female-operated; customizable itineraries celebrating Black culture",
            description: "Black Travel Worldwide is a female-operated agency offering customizable itineraries that celebrate Black culture and heritage, with planning packages for solo travelers, couples, and small to medium-sized groups."
        ),

        // Additional corporate

        TravelAgent(
            agencyName: "Radius Travel",
            city: "Washington",
            state: "DC",
            website: "https://www.radiustravel.com",
            services: [.corporate, .group],
            specialties: "Network of 100+ agencies for multinational companies",
            description: "Radius Travel is a privately held corporate travel management company headquartered in Washington, DC. Operating through a large network of 100+ agencies, they handle travel for multinational companies with global reach."
        ),

        // Additional adventure

        TravelAgent(
            agencyName: "One Nation Travel",
            city: "Princeton",
            state: "NJ",
            website: "https://www.onenationtravel.com",
            services: [.cultural, .escorted, .group, .custom],
            specialties: "Expert-led cultural tours across Europe, Asia, and the Middle East",
            description: "Headquartered in Princeton, NJ with offices in Toronto and Istanbul, One Nation Travel is a top-rated international agency renowned for expert-led cultural tours with personalized itineraries and strong local connections."
        )
    ]

    // MARK: - Filtering Helpers

    static func agents(for service: TravelService) -> [TravelAgent] {
        allAgents.filter { $0.services.contains(service) }
    }

    static func agents(inState state: String) -> [TravelAgent] {
        allAgents.filter { $0.state == state }
    }

    static func search(query: String) -> [TravelAgent] {
        let lowered = query.lowercased()
        return allAgents.filter { agent in
            agent.agencyName.lowercased().contains(lowered) ||
            agent.city.lowercased().contains(lowered) ||
            agent.state.lowercased().contains(lowered) ||
            agent.description.lowercased().contains(lowered) ||
            agent.services.contains(where: { $0.rawValue.lowercased().contains(lowered) }) ||
            (agent.ownerName?.lowercased().contains(lowered) ?? false) ||
            (agent.specialties?.lowercased().contains(lowered) ?? false)
        }
    }

    static func blackOwnedAgencies() -> [TravelAgent] {
        allAgents.filter { $0.services.contains(.heritage) }
    }

    static var totalCount: Int {
        allAgents.count
    }
}
