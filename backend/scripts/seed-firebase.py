"""
seed-firebase.py
────────────────
Seeds Firestore with:
  • 5 sample doctors  (doctors/ collection + users/ collection)
  • 1 admin user      (users/ collection)
  • 3 verified_doctors entries (for doctor sign-up license check)

Requirements:
    pip install firebase-admin

Setup:
    1. Go to Firebase Console → Project Settings → Service Accounts
    2. Click "Generate new private key" → save as serviceAccountKey.json
    3. Place serviceAccountKey.json in the same folder as this script
    4. Run:  python seed-firebase.py
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timezone
import sys
import os

# ─── Config ──────────────────────────────────────────────────────────────────
SERVICE_ACCOUNT_PATH = os.path.join(os.path.dirname(__file__), "serviceAccountKey.json")

def init_firebase():
    if not os.path.exists(SERVICE_ACCOUNT_PATH):
        print("❌  serviceAccountKey.json not found!")
        print("    Download it from Firebase Console → Project Settings → Service Accounts")
        print(f"    Place it at: {SERVICE_ACCOUNT_PATH}")
        sys.exit(1)
    cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred)
    print("✅  Firebase initialized")

# ─── Doctors Seed Data ────────────────────────────────────────────────────────
DOCTORS = [
    {
        "uid": "doctor_seed_001",
        "email": "dr.rajesh.kumar@healthvault.com",
        "fullName": "Dr. Rajesh Kumar",
        "role": "doctor",
        "emailVerified": True,
        "accountStatus": "active",
        "profile": {
            "fullName": "Dr. Rajesh Kumar",
            "specialization": "Cardiology",
            "experience": "12 years",
            "consultationFee": "800",
            "licenseNumber": "MCI-2012-001",
            "phoneNumber": "+91-9876543210",
            "bio": "Senior Cardiologist specializing in interventional cardiology and heart failure management.",
            "availability": "Mon–Fri, 10:00 AM – 5:00 PM",
            "hospital": "City Heart Hospital",
        },
    },
    {
        "uid": "doctor_seed_002",
        "email": "dr.priya.sharma@healthvault.com",
        "fullName": "Dr. Priya Sharma",
        "role": "doctor",
        "emailVerified": True,
        "accountStatus": "active",
        "profile": {
            "fullName": "Dr. Priya Sharma",
            "specialization": "Dermatology",
            "experience": "8 years",
            "consultationFee": "600",
            "licenseNumber": "MCI-2016-002",
            "phoneNumber": "+91-9876543211",
            "bio": "Expert dermatologist focused on skin allergies, acne treatment, and cosmetic dermatology.",
            "availability": "Tue–Sat, 11:00 AM – 6:00 PM",
            "hospital": "SkinCare Clinic",
        },
    },
    {
        "uid": "doctor_seed_003",
        "email": "dr.amit.patel@healthvault.com",
        "fullName": "Dr. Amit Patel",
        "role": "doctor",
        "emailVerified": True,
        "accountStatus": "active",
        "profile": {
            "fullName": "Dr. Amit Patel",
            "specialization": "Orthopedics",
            "experience": "15 years",
            "consultationFee": "1000",
            "licenseNumber": "MCI-2009-003",
            "phoneNumber": "+91-9876543212",
            "bio": "Orthopedic surgeon specializing in joint replacement, sports injuries, and spine disorders.",
            "availability": "Mon–Fri, 9:00 AM – 4:00 PM",
            "hospital": "Bone & Joint Institute",
        },
    },
    {
        "uid": "doctor_seed_004",
        "email": "dr.sunita.mehta@healthvault.com",
        "fullName": "Dr. Sunita Mehta",
        "role": "doctor",
        "emailVerified": True,
        "accountStatus": "active",
        "profile": {
            "fullName": "Dr. Sunita Mehta",
            "specialization": "Pediatrics",
            "experience": "10 years",
            "consultationFee": "500",
            "licenseNumber": "MCI-2014-004",
            "phoneNumber": "+91-9876543213",
            "bio": "Dedicated pediatrician caring for children from newborns to adolescents.",
            "availability": "Mon–Sat, 10:00 AM – 2:00 PM",
            "hospital": "Children's Care Center",
        },
    },
    {
        "uid": "doctor_seed_005",
        "email": "dr.vikram.singh@healthvault.com",
        "fullName": "Dr. Vikram Singh",
        "role": "doctor",
        "emailVerified": True,
        "accountStatus": "active",
        "profile": {
            "fullName": "Dr. Vikram Singh",
            "specialization": "Neurology",
            "experience": "18 years",
            "consultationFee": "1200",
            "licenseNumber": "MCI-2006-005",
            "phoneNumber": "+91-9876543214",
            "bio": "Senior neurologist treating migraines, epilepsy, stroke, and neurodegenerative conditions.",
            "availability": "Wed–Sun, 12:00 PM – 7:00 PM",
            "hospital": "Brain & Spine Hospital",
        },
    },
]

# ─── Verified Doctors (for license check during sign-up) ─────────────────────
VERIFIED_DOCTORS = [
    {"licenseNumber": "MCI-2012-001", "fullName": "Dr. Rajesh Kumar",  "medicalCouncil": "Medical Council of India"},
    {"licenseNumber": "MCI-2016-002", "fullName": "Dr. Priya Sharma",  "medicalCouncil": "Medical Council of India"},
    {"licenseNumber": "MCI-2009-003", "fullName": "Dr. Amit Patel",    "medicalCouncil": "Medical Council of India"},
    {"licenseNumber": "MCI-2014-004", "fullName": "Dr. Sunita Mehta",  "medicalCouncil": "Medical Council of India"},
    {"licenseNumber": "MCI-2006-005", "fullName": "Dr. Vikram Singh",  "medicalCouncil": "Medical Council of India"},
]

# ─── Verified Admins ─────────────────────────────────────────────────────────
VERIFIED_ADMINS = [
    {"adminId": "ADM-001", "fullName": "System Admin",      "department": "Administration"},
    {"adminId": "ADM-002", "fullName": "Hospital Manager",  "department": "Management"},
    {"adminId": "ADM-003", "fullName": "Clinic Admin",      "department": "Operations"},
]

# ─── Admin User ───────────────────────────────────────────────────────────────
ADMIN_USER = {
    "uid": "admin_seed_001",
    "email": "admin@healthvault.com",
    "role": "admin",
    "emailVerified": True,
    "accountStatus": "active",
    "profile": {
        "fullName": "System Admin",
        "phoneNumber": "+91-9000000000",
    },
}

# ─── Seeder Functions ─────────────────────────────────────────────────────────
def seed_doctors(db):
    print("\n📋  Seeding doctors...")
    for doctor in DOCTORS:
        uid = doctor["uid"]
        now = datetime.now(timezone.utc)

        # Write to doctors/ collection (used for patient search)
        doctors_doc = {
            "uid": uid,
            "email": doctor["email"],
            "fullName": doctor["fullName"],
            "emailVerified": doctor["emailVerified"],
            "accountStatus": doctor["accountStatus"],
            "profile": doctor["profile"],
            "createdAt": now,
            "lastLogin": now,
        }
        db.collection("doctors").document(uid).set(doctors_doc)

        # Write to users/ collection (for role-based routing)
        users_doc = {
            "uid": uid,
            "email": doctor["email"],
            "role": doctor["role"],
            "emailVerified": doctor["emailVerified"],
            "accountStatus": doctor["accountStatus"],
            "createdAt": now,
            "lastLogin": now,
        }
        db.collection("users").document(uid).set(users_doc)

        print(f"   ✅  {doctor['fullName']} ({doctor['profile']['specialization']})")

    print(f"   → {len(DOCTORS)} doctors seeded")


def seed_verified_doctors(db):
    print("\n🏥  Seeding verified_doctors (license registry)...")
    for vd in VERIFIED_DOCTORS:
        doc_id = vd["licenseNumber"].replace("-", "_")
        db.collection("verified_doctors").document(doc_id).set(vd)
        print(f"   ✅  {vd['licenseNumber']} — {vd['fullName']}")
    print(f"   → {len(VERIFIED_DOCTORS)} license entries seeded")


def seed_verified_admins(db):
    print("\n🔐  Seeding verified_admins (admin ID registry)...")
    for adm in VERIFIED_ADMINS:
        doc_id = adm["adminId"].replace("-", "_")
        db.collection("verified_admins").document(doc_id).set(adm)
        print(f"   ✅  {adm['adminId']} — {adm['fullName']}")
    print(f"   → {len(VERIFIED_ADMINS)} admin IDs seeded")


def seed_admin(db):
    print("\n👤  Seeding admin user...")
    now = datetime.now(timezone.utc)
    db.collection("users").document(ADMIN_USER["uid"]).set({
        **ADMIN_USER,
        "createdAt": now,
        "lastLogin": now,
    })
    print(f"   ✅  Admin: {ADMIN_USER['email']}")
    print("   ⚠️  NOTE: Create this user in Firebase Auth manually with")
    print(f"       email: {ADMIN_USER['email']}  password: Admin@123")
    print("       Then update the UID in this script to match the Firebase Auth UID")


def main():
    print("=" * 55)
    print("  Smart Health Vault — Firebase Seeder")
    print("=" * 55)

    init_firebase()
    db = firestore.client()

    seed_verified_doctors(db)
    seed_verified_admins(db)
    seed_doctors(db)
    seed_admin(db)

    print("\n" + "=" * 55)
    print("✅  Seeding complete!")
    print("=" * 55)
    print("\nNext steps:")
    print("  1. Deploy indexes:  firebase deploy --only firestore:indexes")
    print("  2. Deploy rules:    firebase deploy --only firestore:rules")
    print("  3. Run the app and sign up a doctor using one of these")
    print("     license numbers to test the doctor sign-up flow:")
    for vd in VERIFIED_DOCTORS:
        print(f"     • {vd['licenseNumber']}  ({vd['fullName']})")

if __name__ == "__main__":
    main()
