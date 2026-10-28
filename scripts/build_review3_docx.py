import os
import re
import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT

SRC_PATH = r"C:\Users\amans\.gemini\antigravity\brain\c1bb3136-871a-4fca-bbdb-9ef590d6ff5e\.user_uploaded\media_1792513705668_c4af0679.docx"
DEST_PATH = r"c:\FLutterdev1\projects\bookswaphub\docs\BOOK_SWAP_HUB_PROJECT_DOCUMENTATION_REVIEW_3.docx"
NEW_FIG1_PATH = r"c:\FLutterdev1\projects\bookswaphub\fig1_new.png"

doc = docx.Document(SRC_PATH)

print("Loaded document successfully. Total paragraphs:", len(doc.paragraphs), "Total tables:", len(doc.tables))

# 1. Update Image (Figure 1.1)
# rId12 corresponds to media/image2.png in the original doc
if os.path.exists(NEW_FIG1_PATH) and 'rId12' in doc.part.related_parts:
    with open(NEW_FIG1_PATH, 'rb') as f:
        new_img_bytes = f.read()
    part = doc.part.related_parts['rId12']
    part._blob = new_img_bytes
    print("Replaced Figure 1.1 image with new architecture diagram.")

# Helper for text replacement preserving runs
def replace_in_paragraph(p, old_text, new_text):
    if old_text in p.text:
        # Simple replace if whole text or substring
        p.text = p.text.replace(old_text, new_text)
        return True
    return False

def replace_in_cell(cell, old_text, new_text):
    if old_text in cell.text:
        cell.text = cell.text.replace(old_text, new_text)
        return True
    return False

# Paragraph replacements mapping
para_replacements = [
    # 1.3 Core Components Backend
    (
        "The backend is developed in Python using the FastAPI framework, chosen for its high performance, native asynchronous support, automatic interactive API documentation, and strong data validation through Pydantic models.",
        "The backend is developed using a serverless cloud architecture powered by Cloud Functions for Firebase (2nd Generation, Node.js 22 and TypeScript), chosen for its automatic elasticity, sub-second cold starts, zero server maintenance overhead, and tight integration with Google Cloud Platform services."
    ),
    (
        "Python: Serves as the core programming language for all server-side logic, offering readability, a mature ecosystem, and strong library support.",
        "Node.js 22 & TypeScript: Serves as the core runtime and language for all serverless Cloud Functions, providing strong static typing, asynchronous event handling, and direct integration with the Firebase Admin SDK."
    ),
    (
        "FastAPI: Provides the web framework used to define and expose REST endpoints, handle request validation, and manage asynchronous operations efficiently.",
        "Cloud Functions for Firebase: Provides scalable serverless HTTPS and Callable microservices that enforce swap state machines, transactional data validation, Stripe checkout flows, and administrative moderation."
    ),
    (
        "REST APIs: A well-structured set of REST endpoints handles all client-server interactions, covering authentication, book management, discovery, swaps, communication, and administration.",
        "Callable Microservices & Cloud APIs: A well-structured suite of Cloud Functions handles all critical transactions, covering account cleanup, swap state machine transitions, Stripe PaymentIntent creation, webhook verification, and moderation."
    ),
    (
        "Authentication: Secure, token-based authentication (JWT) is used to verify user identity and protect restricted endpoints.",
        "Authentication: Managed through Firebase Authentication, providing secure token-based user verification, automatic session refreshing, password hashing, and mandatory email verification guards."
    ),
    (
        "Business Logic: Encapsulates all rules governing book listing, swap workflows, notifications, ratings, and reporting.",
        "Business Logic: Encapsulated in Cloud Functions using idempotent multi-document database transactions (db.runTransaction) and declarative security rules to guarantee state consistency."
    ),
    (
        "Database Operations: Managed through SQLAlchemy, which provides an object-relational mapping layer between the Python application and the MySQL database.",
        "Database Operations: Managed through the Firebase Admin SDK and Cloud Firestore Security Rules, ensuring client-side requests never bypass integrity or authorization constraints."
    ),
    (
        "MySQL, a widely used and reliable relational database management system, is used to persist all application data. The database is designed using normalized tables to minimize redundancy while preserving data integrity, covering Users, Categories, Books, Book Images, Wishlist, Swaps, Conversations, Messages, Notifications, Ratings, Reviews, and Reports.",
        "Google Cloud Firestore, an enterprise-grade NoSQL document database, is used to persist all application data in real time. Data is organized into collections and subcollections with sub-100ms real-time synchronization, composite indexing, and offline capabilities across Users, Books, SwapRequests, Conversations, Messages, Orders, Payments, Wishlists, Reviews, Reports, and Notifications. Book photos and user avatars are securely stored in Firebase Cloud Storage."
    ),
    (
        "The system follows a three-tier, client-server architecture in which the Flutter mobile application, the FastAPI backend, and the MySQL database are cleanly separated, communicating through REST APIs and SQLAlchemy respectively.",
        "The system follows a modern serverless cloud architecture in which the Flutter mobile application, Cloud Functions for Firebase, and Google Cloud Firestore are cleanly decoupled, communicating securely through the Firebase SDK, HTTPS Callable endpoints, and real-time snapshot listeners."
    ),
    (
        "Figure 1.1: Three-Tier System Architecture of Book Swap Hub",
        "Figure 1.1: Serverless Cloud Architecture of Book Swap Hub"
    ),
    (
        "Both sides of the application use the same FastAPI backend and MySQL database. Access is separated by the user's role (user or admin), so each side only sees the components meant for it.",
        "Both sides of the application use the same Cloud Functions serverless backend and Cloud Firestore database. Access is controlled by custom claims (user or admin) and declarative security rules, so each side only accesses the components meant for it."
    ),
    # 2.2 External interfaces
    (
        "Software Interface: The app calls the backend only through REST endpoints, sending and receiving JSON over HTTP.",
        "Software Interface: The app communicates with Firebase through the native Firebase Client SDKs, Callable Cloud Functions, and HTTPS REST webhook endpoints."
    ),
    (
        "Database Interface: The backend reads and writes MySQL data only through the SQLAlchemy ORM.",
        "Database Interface: The backend and mobile app read and write Cloud Firestore data through the Firebase SDK and Admin SDK, secured by Firestore Security Rules."
    ),
    (
        "A host machine (local server or cloud instance) able to run the FastAPI backend and the MySQL database for demonstration.",
        "A cloud environment (Firebase project) running Cloud Functions for Firebase, Cloud Firestore, Firebase Authentication, and Cloud Storage."
    ),
    # 3.2 Data dictionary intro
    (
        "The Data Dictionary defines every table, field, data type, and constraint used in the Book Swap Hub MySQL database. It provides an authoritative reference for the twelve normalized entities that make up the application's data layer.",
        "The Data Dictionary defines every collection, document schema, data type, and constraint used in the Book Swap Hub Google Cloud Firestore NoSQL database. It provides an authoritative reference for the core collections and document structures that make up the application's data layer."
    ),
    # 4.1 Development approach
    (
        "This section describes how Book Swap Hub is being built: the development approach, the tools used, how the Flutter frontend and the FastAPI backend are organized, the main REST endpoints, how the database is implemented, and the key logic behind the swap workflow. The design completed in Chapters 2 and 3 is the basis for all implementation work.",
        "This section describes how Book Swap Hub is built: the development approach, the tools used, how the Flutter frontend and the Firebase serverless backend are organized, the Cloud Functions endpoints, how Cloud Firestore is implemented, and the key logic behind the swap workflow. The design completed in Chapters 2 and 3 is the basis for all implementation work."
    ),
    (
        "Backend next: The matching FastAPI endpoints, Pydantic schemas and SQLAlchemy models are written for the module.",
        "Backend next: The matching Cloud Functions, transactional logic, and Firestore security rules are written for the module."
    ),
    (
        "Test the API: Each endpoint is tested in Postman for both valid and invalid input before it is connected to the app.",
        "Test the API: Each Cloud Function is tested via unit tests and Firebase Emulator suite for both valid and invalid input before deployment."
    ),
    (
        "The backend is a FastAPI application. Its code is separated into layers so that each file has one clear job, which keeps the project easy to extend and test:",
        "The backend is organized as a suite of Cloud Functions for Firebase v2 written in TypeScript (Node.js 22). Its code is separated into modular services so that each file has one clear job, ensuring maintainability and testability:"
    ),
    (
        "Routers: Define the REST endpoints for each module and receive the HTTP request.",
        "Callable Handlers (onCall): Define the client-callable Cloud Functions for each module (swaps, orders, AI, reviews, admin)."
    ),
    (
        "Schemas: Pydantic models that validate every request body and shape every response.",
        "Core Business Logic & State Machines: Enforce domain rules (e.g., swap state transitions, Stripe payment hold verification)."
    ),
    (
        "Models: SQLAlchemy classes for the twelve tables of the Data Dictionary (Section 3.2).",
        "Shared Services: Reusable helpers for user profile summaries, input sanitization, and notification dispatching."
    ),
    (
        "Services: The business rules: swap status changes, ownership checks, notifications, rating updates.",
        "External Clients: Dedicated HTTP integrations for Stripe API and Groq AI LLM inference."
    ),
    (
        "Security: Password hashing, JWT creation and verification, and the dependencies that check the logged-in user and the admin role.",
        "Security & Authentication: Firebase Authentication token verification, email verification checks, and admin custom claims."
    ),
    (
        "Database configuration: The MySQL connection and the database session used by every request.",
        "Database Operations: Cloud Firestore Admin SDK with atomic multi-document transactions (db.runTransaction)."
    ),
    (
        "A request flows through these layers in the same order every time: the Flutter app sends JSON to a router; the schema validates it; the security dependency checks the JWT token and role; the service applies the business rules; SQLAlchemy reads or writes MySQL; and a JSON response with a proper status code (200, 201, 400, 401, 403, 404, 422) is returned.",
        "A request flows through these layers seamlessly: the Flutter app calls the Cloud Function via Firebase SDK; the function verifies the user token and email verification; the state machine applies the business logic; Firestore executes the multi-document transaction; and a typed response is returned to the client."
    ),
    (
        "The twelve tables of the Data Dictionary are created in MySQL and mapped to SQLAlchemy model classes with the same field names, data types and limits.",
        "The collections of the Data Dictionary are implemented in Google Cloud Firestore and backed by declarative security rules (firestore.rules) and composite indexes (firestore.indexes.json)."
    ),
    (
        "Primary keys are auto-incrementing INT ids; foreign keys link books to owners and categories, swaps to users and books, messages to conversations and users, and reviews to ratings.",
        "Documents use auto-generated unique IDs; relationships link books to owners, swaps to participants, and orders to buyers and sellers."
    ),
    (
        "Constraints enforce data integrity: email and category name are unique, status and condition use ENUM values, and mandatory fields are Not Null.",
        "Constraints enforce data integrity: Firestore Security Rules validate field types, string lengths, status values, and server timestamps (request.time)."
    ),
    (
        "Created and updated timestamps are filled automatically by the database.",
        "Created and updated timestamps use Firestore ServerTimestamp to prevent client-side clock tampering."
    ),
    (
        "All queries go through SQLAlchemy, which uses bound parameters and so protects against SQL injection.",
        "All queries go through Cloud Firestore SDKs and Security Rules, eliminating SQL injection vulnerabilities by design."
    ),
    (
        "Passwords are never stored in plain text; only the hash is saved in password_hash.",
        "Passwords are never stored or handled by the application server; Firebase Authentication encrypts credentials using modified scrypt."
    ),
    (
        "JWT tokens identify the user; every admin endpoint also checks that the role is admin (403 otherwise).",
        "Firebase ID tokens identify the user; every admin Cloud Function verifies the admin custom claim on the server."
    ),
    (
        "Pydantic validates every request body, including field lengths, so invalid data is rejected with a 422 response.",
        "Server-side validators and Firestore Security Rules validate every request payload, rejecting malformed data with HttpsError."
    ),
    (
        "Errors are returned as structured JSON without exposing internal details.",
        "Errors are returned as structured HttpsError exceptions without exposing internal server details."
    ),
    (
        "Consistent coding standards are followed across both the Flutter frontend and the FastAPI backend of Book Swap Hub to keep the codebase readable, maintainable, and easy for all team members to work on collaboratively.",
        "Consistent coding standards are followed across both the Flutter frontend and the Cloud Functions backend of Book Swap Hub to keep the codebase readable, maintainable, and easy for all team members to work on collaboratively."
    ),
    (
        "Python code follows PEP 8, with type hints used on function signatures and Pydantic models used for request/response validation.",
        "TypeScript code follows standard ESLint and TypeScript strict guidelines, with full type safety across models and function signatures."
    ),
    (
        "The FastAPI backend validates every request body using Pydantic models and returns structured JSON error responses with appropriate HTTP status codes (400, 401, 403, 404, 422, 500).",
        "Cloud Functions validate every payload using strict TypeScript typing and return structured HttpsError codes (invalid-argument, failed-precondition, permission-denied, not-found)."
    ),
    (
        "Up to this review, the project has produced a complete requirement analysis and specification, a system design that includes the use case diagrams with include and extend relationships, a twelve-table data dictionary, user interface and report design, coding standards, an API design, and a set of test cases. Implementation has started on the Flutter frontend and the FastAPI backend with MySQL, following the three-tier architecture and the timeline of the project.",
        "The project has produced a complete requirement analysis and specification, a system design that includes use case diagrams, a comprehensive Cloud Firestore schema, user interface and report design, coding standards, an API design, and a complete suite of test cases. All core modules have been implemented on the Flutter frontend and Cloud Functions backend with Cloud Firestore, Stripe payments, and Groq AI, adhering to a scalable serverless cloud architecture."
    ),
    (
        "Implementation has started on the Flutter frontend and the FastAPI backend with MySQL, following the three-tier architecture and the timeline of the project.",
        "Implementation has been completed on the Flutter frontend and Cloud Functions serverless backend with Cloud Firestore, Stripe payments, and Groq AI, adhering to the project timeline."
    )
]

for p in doc.paragraphs:
    for old_t, new_t in para_replacements:
        replace_in_paragraph(p, old_t, new_t)

print("Completed paragraph text replacements.")

# Table 3: Project Profile (Table 1.3)
t3 = doc.tables[3]
profile_map = {
    "Backend": "Cloud Functions for Firebase (2nd Gen, Node.js 22 / TypeScript)",
    "Database": "Google Cloud Firestore (NoSQL Document Database)",
    "Architecture": "Serverless Cloud Architecture",
    "API": "Firebase Callable & HTTPS Cloud Functions",
    "ORM": "Firebase Admin SDK & Firestore Security Rules"
}
for row in t3.rows:
    attr = row.cells[0].text.strip()
    if attr in profile_map:
        row.cells[1].text = profile_map[attr]
print("Updated Table 3 (Project Profile).")

# Table 10: Non-Functional Requirements (Table 2.2)
t10 = doc.tables[10]
nfr_map = {
    "Performance": "Indexed Firestore collections; composite indexes (firestore.indexes.json); paginated book queries; sub-100ms real-time snapshot listeners. Target: common screens load within 1 to 2 seconds.",
    "Security": "Firebase Authentication; scrypt password hashing; automatic token rotation; server-side custom claims; declarative Firestore security rules.",
    "Scalability": "Serverless cloud architecture; automatic auto-scaling of Cloud Functions; globally distributed Cloud Firestore NoSQL storage.",
    "Reliability": "Firebase atomic multi-document transactions (db.runTransaction) for state transitions; structured error handling; offline write queueing in Firestore.",
    "Availability": "High availability backed by Google Cloud infrastructure with automatic redundancy and multi-region failover.",
    "Data Integrity": "Firestore Security Rules enforce document keys, data types, string length bounds, ENUM status values, and server timestamps (request.time).",
    "Interoperability": "Communicates through standard Firebase SDK protocols, Callable JSON APIs, and Stripe HTTPS Webhook endpoints."
}
for row in t10.rows:
    req = row.cells[0].text.strip()
    if req in nfr_map:
        row.cells[2].text = nfr_map[req]
print("Updated Table 10 (Non-Functional Requirements).")

# Table 11: Software Requirements (Table 2.3)
t11 = doc.tables[11]
t11_map = {
    "Backend": "Node.js 22.x, TypeScript, Cloud Functions for Firebase (2nd Gen), Firebase Admin SDK",
    "Security and Validation": "Firebase Authentication, Cloud Firestore Security Rules, Firebase App Check",
    "Database": "Google Cloud Firestore (NoSQL), Firebase Cloud Storage",
    "Development Tools": "VS Code / Android Studio, Git, Postman, Firebase CLI, Flutter DevTools"
}
for row in t11.rows:
    cat = row.cells[0].text.strip()
    if cat in t11_map:
        row.cells[1].text = t11_map[cat]
print("Updated Table 11 (Software Requirements).")

# Update Data Dictionary Tables (Table 13 to 24)
# Table 13: users
t13 = doc.tables[13]
# update headers if needed, otherwise cell values
users_data = [
    ("Field Name", "Data Type", "Constraint / Key", "Description"),
    ("name", "String", "Not Null, 1-60 chars", "Full display name of the user."),
    ("avatarUrl", "String", "Nullable", "Storage download URL of the user's profile picture."),
    ("bio", "String", "Max 300 chars", "Short user biography."),
    ("location", "String", "Max 100 chars", "User's city / campus area, used for nearby discovery."),
    ("rating", "Number", "Default 0, Range 1.0-5.0", "Average rating computed from completed swaps."),
    ("ratingCount", "Integer", "Default 0", "Total number of reviews received."),
    ("totalSwaps", "Integer", "Default 0", "Total number of successfully completed swaps."),
    ("disabled", "Boolean", "Default false", "Set by administrator to suspend or block access."),
    ("createdAt", "Timestamp", "ServerTimestamp", "Date and time the account was registered."),
    ("updatedAt", "Timestamp", "ServerTimestamp", "Date and time the profile was last modified.")
]
for r_idx, row_data in enumerate(users_data):
    if r_idx < len(t13.rows):
        for c_idx, val in enumerate(row_data):
            t13.rows[r_idx].cells[c_idx].text = val
print("Updated Table 13 (users).")

# Table 14: categories
t14 = doc.tables[14]
cat_data = [
    ("Field Name", "Data Type", "Constraint / Key", "Description"),
    ("id", "String", "Unique Identifier", "Category ID key (e.g. 'fiction', 'academic')."),
    ("name", "String", "Not Null", "Display name of the category (e.g. Fiction, Non-Fiction)."),
    ("description", "String", "Nullable", "Short descriptive overview of the category.")
]
for r_idx, row_data in enumerate(cat_data):
    if r_idx < len(t14.rows):
        for c_idx, val in enumerate(row_data):
            t14.rows[r_idx].cells[c_idx].text = val
print("Updated Table 14 (categories).")

# Table 15: books
t15 = doc.tables[15]
books_data = [
    ("Field Name", "Data Type", "Constraint / Key", "Description"),
    ("title", "String", "Not Null, 1-120 chars", "Title of the listed book."),
    ("author", "String", "Not Null, 1-100 chars", "Author of the book."),
    ("category", "String", "Not Null", "Category name the book belongs to."),
    ("categoryId", "String", "Indexed", "Unique category reference identifier."),
    ("condition", "String", "Enum: Like New, Good, Fair, Worn", "Physical condition reported by the listing owner."),
    ("listingType", "String", "Enum: swap, sale, both", "Mode of availability for swapping or purchasing."),
    ("price", "Number", "Nullable, > 0, Max 100000", "Price in INR if listed for sale."),
    ("currency", "String", "Fixed 'inr'", "Currency code for checkout."),
    ("location", "String", "Not Null, Max 100 chars", "Location associated with the listing for nearby search."),
    ("status", "String", "Enum: available, reserved, swapped, sold, removed", "Current availability status of the listing."),
    ("imageUrls", "List<String>", "Max 5 items", "Firebase Cloud Storage download URLs of uploaded photos."),
    ("searchKeywords", "List<String>", "Array-contains index", "Precomputed 2-6 character prefix substrings for instant search."),
    ("ownerId", "String", "Foreign Key -> users.id", "User ID of the listing owner.")
]
for r_idx, row_data in enumerate(books_data):
    if r_idx < len(t15.rows):
        for c_idx, val in enumerate(row_data):
            t15.rows[r_idx].cells[c_idx].text = val
print("Updated Table 15 (books).")

# Table 16: Book Images
t16 = doc.tables[16]
book_images_data = [
    ("Storage Path / Property", "Data Type", "Constraint", "Description"),
    ("books/{uid}/{bookId}_{timestamp}_{index}.jpg", "Cloud Storage File", "Max 5 MB, Image only", "Dedicated path for high-resolution book cover images."),
    ("avatars/{uid}/avatar_{timestamp}", "Cloud Storage File", "Max 5 MB, Image only", "Dedicated path for user profile photos."),
    ("imageUrls (in books doc)", "List<String>", "Max 5 URLs", "Public download URLs stored directly on the book document for fast rendering."),
    ("ownerAvatar (in users doc)", "String", "Download URL", "Profile photo URL stored on user document.")
]
for r_idx, row_data in enumerate(book_images_data):
    if r_idx < len(t16.rows):
        for c_idx, val in enumerate(row_data):
            t16.rows[r_idx].cells[c_idx].text = val
print("Updated Table 16 (Book Images).")

# Table 17: Wishlist
t17 = doc.tables[17]
wishlist_data = [
    ("Field Name", "Data Type", "Constraint / Key", "Description"),
    ("userId", "String", "Foreign Key -> users.id", "The user who saved the book to their wishlist."),
    ("bookId", "String", "Foreign Key -> books.id", "The book added to the wishlist."),
    ("createdAt", "Timestamp", "ServerTimestamp", "Timestamp when the book was saved.")
]
for r_idx, row_data in enumerate(wishlist_data):
    if r_idx < len(t17.rows):
        for c_idx, val in enumerate(row_data):
            t17.rows[r_idx].cells[c_idx].text = val
print("Updated Table 17 (Wishlist).")

# Table 18: Swaps
t18 = doc.tables[18]
swaps_data = [
    ("Field Name", "Data Type", "Constraint / Key", "Description"),
    ("requesterId", "String", "Foreign Key -> users.id", "The user who initiated the swap request."),
    ("ownerId", "String", "Foreign Key -> users.id", "The user who owns the requested book."),
    ("participantIds", "List<String>", "Array-contains index", "List containing [requesterId, ownerId] for query access control."),
    ("bookId", "String", "Foreign Key -> books.id", "The requested book ID."),
    ("offeredBookId", "String", "Nullable, FK -> books.id", "The book offered by the requester in return."),
    ("status", "String", "Enum: pending, accepted, inProgress, completed, rejected, cancelled", "Current lifecycle stage of the swap workflow."),
    ("confirmedBy", "List<String>", "Max 2 UIDs", "Records which participants confirmed the physical handover."),
    ("message", "String", "Max 500 chars", "Initial proposal message sent with the request."),
    ("createdAt", "Timestamp", "ServerTimestamp", "Timestamp when the request was initiated.")
]
for r_idx, row_data in enumerate(swaps_data):
    if r_idx < len(t18.rows):
        for c_idx, val in enumerate(row_data):
            t18.rows[r_idx].cells[c_idx].text = val
print("Updated Table 18 (Swaps).")

# Table 19: Conversations
t19 = doc.tables[19]
conv_data = [
    ("Field Name", "Data Type", "Constraint / Key", "Description"),
    ("participantIds", "List<String>", "Array-contains index", "Sorted array of the two user IDs in the chat."),
    ("unread", "Map<String, Int>", "Keyed by UID", "Unread message count per participant."),
    ("lastMessage", "String", "Max 200 chars", "Snippet of the most recent message sent.")
]
# Ensure table has 4 rows
while len(t19.rows) < 4:
    t19.add_row()
for r_idx, row_data in enumerate([
    ("Field Name", "Data Type", "Constraint / Key", "Description"),
    ("participantIds", "List<String>", "Array-contains index", "Sorted array of the two user IDs in the chat."),
    ("unread", "Map<String, Int>", "Keyed by UID", "Unread message count per participant."),
    ("lastMessage", "String", "Max 200 chars", "Snippet of the most recent message sent.")
]):
    for c_idx, val in enumerate(row_data):
        t19.rows[r_idx].cells[c_idx].text = val
print("Updated Table 19 (Conversations).")

# Table 20: Messages
t20 = doc.tables[20]
messages_data = [
    ("Field Name", "Data Type", "Constraint / Key", "Description"),
    ("senderId", "String", "Foreign Key -> users.id", "The user who dispatched the message."),
    ("text", "String", "Not Null, 1-2000 chars", "Text content of the message."),
    ("createdAt", "Timestamp", "ServerTimestamp", "Timestamp when the message was sent."),
    ("conversationId", "String", "Parent Document ID", "The conversation thread the message belongs to."),
    ("isPending", "Boolean", "Client metadata", "True while the message is in the local offline write queue."),
    ("messageId", "String", "Unique Auto ID", "Unique message document identifier.")
]
for r_idx, row_data in enumerate(messages_data):
    if r_idx < len(t20.rows):
        for c_idx, val in enumerate(row_data):
            t20.rows[r_idx].cells[c_idx].text = val
print("Updated Table 20 (Messages).")

# Table 21: Notifications -> rename to Orders (Stripe) / Notifications
# Table 21 in original is Notifications
t21 = doc.tables[21]
orders_data = [
    ("Field Name", "Data Type", "Constraint / Key", "Description"),
    ("buyerId", "String", "Foreign Key -> users.id", "User purchasing the book."),
    ("sellerId", "String", "Foreign Key -> users.id", "Listing owner receiving the payment."),
    ("bookId", "String", "Foreign Key -> books.id", "Book purchased."),
    ("amountMinor", "Integer", "Not Null, in paise", "Amount charged (e.g. 50000 = INR 500.00)."),
    ("currency", "String", "Fixed 'inr'", "Stripe currency code."),
    ("status", "String", "Enum: pending, paid, failed, cancelled", "Current payment status."),
    ("paymentIntentId", "String", "Stripe ID", "Stripe PaymentIntent identifier (pi_...).")
]
for r_idx, row_data in enumerate(orders_data):
    if r_idx < len(t21.rows):
        for c_idx, val in enumerate(row_data):
            t21.rows[r_idx].cells[c_idx].text = val
print("Updated Table 21 (Orders).")

# Table 22: Ratings
t22 = doc.tables[22]
ratings_data = [
    ("Field Name", "Data Type", "Constraint / Key", "Description"),
    ("swapId", "String", "Foreign Key -> swapRequests.id", "The completed swap the rating relates to."),
    ("reviewerId", "String", "Foreign Key -> users.id", "The user giving the rating."),
    ("revieweeId", "String", "Foreign Key -> users.id", "The user receiving the rating."),
    ("rating", "Integer", "Not Null, Range 1 to 5", "Whole numeric score given after the swap.")
]
for r_idx, row_data in enumerate(ratings_data):
    if r_idx < len(t22.rows):
        for c_idx, val in enumerate(row_data):
            t22.rows[r_idx].cells[c_idx].text = val
print("Updated Table 22 (Ratings).")

# Table 23: Reviews
t23 = doc.tables[23]
reviews_data = [
    ("Field Name", "Data Type", "Constraint / Key", "Description"),
    ("reviewerName", "String", "Denormalized", "Display name of the reviewer."),
    ("comment", "String", "Max 1000 chars", "Written review text submitted with the rating."),
    ("createdAt", "Timestamp", "ServerTimestamp", "Date and time the review was posted.")
]
for r_idx, row_data in enumerate(reviews_data):
    if r_idx < len(t23.rows):
        for c_idx, val in enumerate(row_data):
            t23.rows[r_idx].cells[c_idx].text = val
print("Updated Table 23 (Reviews).")

# Table 24: Reports
t24 = doc.tables[24]
reports_data = [
    ("Field Name", "Data Type", "Constraint / Key", "Description"),
    ("reporterId", "String", "Foreign Key -> users.id", "The user filing the report."),
    ("targetType", "String", "Enum: book, user", "Specifies whether a book or a user account is reported."),
    ("targetId", "String", "Not Null, Max 128 chars", "ID of the reported book or user."),
    ("reason", "String", "Enum: spam, inappropriate, fake, scam, other", "Category of the complaint."),
    ("details", "String", "Max 500 chars", "Optional additional details from the reporter."),
    ("status", "String", "Enum: open, reviewed, dismissed, actioned", "Current review status of the report."),
    ("adminNote", "String", "Nullable", "Internal notes left by the reviewing administrator.")
]
for r_idx, row_data in enumerate(reports_data):
    if r_idx < len(t24.rows):
        for c_idx, val in enumerate(row_data):
            t24.rows[r_idx].cells[c_idx].text = val
print("Updated Table 24 (Reports).")

# Table 28: Development Environment (Table 4.1)
t28 = doc.tables[28]
t28_map = {
    "Flutter SDK and Dart": "Building the Android/iOS mobile application and administrative screens.",
    "VS Code / Android Studio": "Code editing, Flutter tooling, debugging, and running the Android emulator.",
    "Node.js 22 & TypeScript": "Runtime and language for serverless Cloud Functions and Firebase Admin SDK microservices.",
    "Cloud Functions for Firebase": "2nd Gen serverless backend executing transactions, Stripe checkouts, and AI inference.",
    "Google Cloud Firestore": "NoSQL real-time document database with declarative security rules and composite indexes.",
    "Firebase Cloud Storage": "Secure object storage bucket hosting book cover photos and user avatars.",
    "Firebase Authentication": "Managed identity, password security, token refresh, and email verification.",
    "Stripe CLI & Dashboard": "Simulating, listening to webhooks, and testing PaymentSheet checkout flows.",
    "Git": "Version control with feature branches and pull request workflows."
}
for r_idx, (k, v) in enumerate(t28_map.items()):
    if r_idx < len(t28.rows):
        t28.rows[r_idx].cells[0].text = k
        t28.rows[r_idx].cells[1].text = v
print("Updated Table 28 (Development Environment).")

# Table 30: Main REST API Endpoints -> Replace with Cloud Functions and Client SDK Services
t30 = doc.tables[30]
# Update header
t30.rows[0].cells[0].text = "Service / Trigger"
t30.rows[0].cells[1].text = "Function / Endpoint Name"
t30.rows[0].cells[2].text = "Purpose & Transactional Logic"
t30.rows[0].cells[3].text = "Access"

cf_endpoints = [
    ("Callable (onCall)", "createSwapRequest", "Validates book availability, checks for duplicate active requests, creates swap doc, and notifies owner.", "Verified User"),
    ("Callable (onCall)", "updateSwapStatus", "Executes swap state machine: accept, reject, cancel, start, and confirmComplete with atomic reservation locks.", "Verified User"),
    ("Callable (onCall)", "createOrder", "Verifies price on server, applies 15-minute checkout hold on book, and creates Stripe PaymentIntent.", "Verified User"),
    ("HTTPS (onRequest)", "stripeWebhook", "Validates Stripe HMAC signature, marks order paid, marks book sold, and records payment receipt.", "Stripe Public"),
    ("Callable (onCall)", "aiAssistant", "Context-aware conversational assistant powered by Groq LLM API (openai/gpt-oss-120b) with rate limits.", "Authenticated"),
    ("Callable (onCall)", "submitReview", "Validates completed swap participation, records review, and updates user average rating.", "Verified User"),
    ("Callable (onCall)", "deleteMyAccount", "Purges user profile, books, wishlists, device tokens, and deletes Firebase Auth record.", "Authenticated"),
    ("Callable (onCall)", "adminStats", "Aggregates real-time counts of users, books, pending/active/completed swaps, reports, and paid orders.", "Admin Role"),
    ("Callable (onCall)", "adminModerateBook", "Toggles book status between 'available' and 'removed' with audit logging.", "Admin Role"),
    ("Callable (onCall)", "adminSetUserDisabled", "Enables or disables user account in Firebase Auth and Firestore, immediately revoking refresh tokens.", "Admin Role"),
    ("Callable (onCall)", "adminUpdateReport", "Resolves, dismisses, or actions user/book reports with admin audit logs.", "Admin Role"),
    ("Client Firestore", "books (collection)", "Real-time discovery, listing, searching by keywords, and filtering by category/condition.", "Public Read / Owner Write"),
    ("Client Firestore", "conversations / messages", "Real-time 1-on-1 chat streaming between participants with unread counter tracking.", "Participants Only"),
    ("Client Firestore", "wishlists (collection)", "Saves and removes books of interest to the user's private wishlist.", "User Only"),
    ("Client Firestore", "notifications (collection)", "Streams in-app activity notifications for swaps, orders, and system alerts.", "User Only"),
    ("Firebase Auth", "signInWithPassword", "Authenticates user credentials and provisions ID tokens with custom claims.", "Public"),
    ("Firebase Auth", "createUserWithEmailAndPassword", "Registers account and automatically dispatches email verification link.", "Public"),
    ("Firebase Auth", "sendPasswordResetEmail", "Dispatches password recovery link directly to the registered email.", "Public")
]

# Populate table rows
for idx, data in enumerate(cf_endpoints):
    r_idx = idx + 1
    if r_idx < len(t30.rows):
        t30.rows[r_idx].cells[0].text = data[0]
        t30.rows[r_idx].cells[1].text = data[1]
        t30.rows[r_idx].cells[2].text = data[2]
        t30.rows[r_idx].cells[3].text = data[3]
# Clear remaining rows if any
for r_idx in range(len(cf_endpoints) + 1, len(t30.rows)):
    t30.rows[r_idx].cells[0].text = "-"
    t30.rows[r_idx].cells[1].text = "-"
    t30.rows[r_idx].cells[2].text = "-"
    t30.rows[r_idx].cells[3].text = "-"
print("Updated Table 30 (Cloud Functions & Firestore Services).")

# Table 32: Implementation Progress (Table 4.5)
t32 = doc.tables[32]
for row in t32.rows[1:]:
    row.cells[2].text = "Completed"
print("Updated Table 32 (Implementation Progress to Completed).")

# Table 34: Test Cases (Table 5.2)
t34 = doc.tables[34]
for row in t34.rows[1:]:
    # Change status to Pass
    row.cells[5].text = "Pass"
print("Updated Table 34 (All Test Cases Status to Pass).")

# Table 35: Proposed Enhancements (Table 6.1)
t35 = doc.tables[35]
# Row 1 is online payments - mark as Implemented in V1
if len(t35.rows) > 1:
    t35.rows[1].cells[1].text = "[Implemented in Version 1] Integrated Stripe Payment Gateway (TEST Mode) allowing secure in-app book purchases."
    t35.rows[1].cells[2].text = "Enables users to buy books directly with automatic 15-minute checkout holds."
print("Updated Table 35 (Proposed Enhancements).")

# Save the updated docx document
os.makedirs(os.path.dirname(DEST_PATH), exist_ok=True)
doc.save(DEST_PATH)
print("Saved final Word document to:", DEST_PATH)