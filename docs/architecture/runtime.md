                    mausoleum.json
                          │
                          ▼
                  MausoleumProfile
                          │
                          ├── allowed rooms
                          ├── room weights
                          ├── architecture
                          ├── global rules
                          └── global lighting
                          │
                          ▼
                  RoomPurposeResolver
                          │
                          ▼
                     tomb.json
                          │
                          ▼
                  RoomProfileLoader
                          │
                          ▼
                 ResolvedRoomProfile
                          │
             ┌────────────┼────────────┐
             ▼            ▼            ▼
        Composition     Props       Fixtures
          Planner      Resolver      Resolver
             │            │            │
             └────────────┼────────────┘
                          ▼
                    Presentation