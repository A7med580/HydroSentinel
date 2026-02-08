# HydroSentinel

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)

**HydroSentinel** is a Flutter-based industrial water intelligence platform. It analyzes Cooling Tower and RO chemistry to detect Scaling, Corrosion, and Fouling risks. The app provides automated engineering indices, health scoring, and prioritized maintenance recommendations to optimize system performance.

---

---

## 🏗️ Architecture

```mermaid
graph TD
    User[User] -->|Login| Auth[Auth Feature]
    Auth -->|Session| SupabaseAuth[Supabase Auth]
    
    User -->|View Factories| FactoriesUI[Factories Screen]
    FactoriesUI -->|Watch| FactoryRepo[Factory Repository]
    
    FactoryRepo -->|Sync| SyncManager[Sync Manager]
    
    SyncManager -->|Fetch Folders| GDrive[Google Drive API]
    SyncManager -->|Store Metadata| SupabaseDB[Supabase DB]
    
    GDrive -->|New Excel File| AnalysisEngine[Analysis Engine]
    AnalysisEngine -->|Results| SupabaseDB
    
    SupabaseDB -->|Real-time Updates| FactoriesUI
```

### Value Extraction Architecture
```mermaid
graph TD
    RawFile[Raw .xlsx] --> Normalizer[ExcelNormalizer]
    Normalizer --> Structured[Normalized Table]
    Structured --> Validator[ExcelValidator]
    Validator --> Parser[UniversalParser]
    Parser --> DomainModels[CoolingTowerData / ROData]
    
    Generator[TemplateGenerator] --> TemplateFile[.xlsx Export]
```

### File Upload Flow
```mermaid
graph TD
    A[User taps Upload FAB] --> B[File picker opens]
    B --> C{User selects .xlsx file?}
    C -->|Cancel| D[Close picker]
    C -->|Yes| E[Validate file size]
    E -->|Greater than 10MB| F[Show error: File too large]
    E -->|Less than 10MB| G[Upload to Storage]
    G --> H[Show: Syncing...]
    H --> I[Trigger sync process]
    I --> J[Refresh factory data]
    J --> K[Show: File processed!]
```


## 🚀 Features

-   **Advanced Chemistry Analysis**: Automatically calculates indices like LSI, RSI, PSI, and more.
-   **Risk Assessment**: Detects Scaling, Corrosion, and Fouling risks with severity scoring.
-   **Data Import**: Seamlessly import data via Excel (`.xlsx`) templates.
-   **Maintenance Recommendations**: Generates actionable, prioritized maintenance tasks.
-   **Visualization**: View trends and health scores through intuitive dashboards.

## 🛠️ Installation

1.  Clone the repository:
    ```bash
    git clone https://github.com/A7med580/HydroSentinel.git
    ```
2.  Navigate to the project directory:
    ```bash
    cd HydroSentinel
    ```
3.  Install dependencies:
    ```bash
    flutter pub get
    ```
4.  Run the app:
    ```bash
    flutter run
    ```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
*Built with ❤️ using Flutter.*
