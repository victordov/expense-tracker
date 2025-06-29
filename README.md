# ReceiptWise

ReceiptWise is a lightweight iOS application for digitizing and organizing purchase receipts. Simply scan a receipt with your camera and ReceiptWise automatically extracts the store information, line items, totals, and taxes. Everything is stored locally with the option to sync to Google Drive or export to CSV.

## Features

- **Smart OCR** – Uses Apple's Vision framework to recognize text on receipts with support for English and Romanian.
- **Detailed Parsing** – Extracts store names, dates, itemized purchases, totals and taxes.
- **Google Drive Sync** – Sign in with your Google account and back up receipts as CSV files.
- **CSV Export** – Export individual or all receipts as CSV for reporting or spreadsheet analysis.
- **ChatGPT Parsing** – Optionally send recognized text to OpenAI's ChatGPT API for more accurate extraction of store, servant, date and totals.
- **SwiftUI Interface** – Modern, user‑friendly design with an onboarding flow and settings screen.

## Getting Started

1. Clone this repository.
2. Open `expense-tracker-v1.xcodeproj` in Xcode (Xcode 15 or later recommended).
3. Build and run on an iOS device or simulator running iOS 17 or later.

To enable Google Drive sync you will need to add your OAuth Client ID in `GoogleDriveService.swift`.
To use ChatGPT-based parsing set an `OPENAI_API_KEY` environment variable before running the app.

## Contributing

Pull requests are welcome! Whether it's bug fixes, new features or improved documentation, feel free to open an issue or submit a PR.

## License

ReceiptWise is released under the MIT License. See [LICENSE](LICENSE) for details.
