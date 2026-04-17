# Customer Semi-Normalized Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current oversized `Customer` model with a semi-normalized customer domain that supports richer P2P collection data, flexible Excel imports, and cleaner dashboard queries.

**Architecture:** Keep `customers` as the lightweight operational snapshot, then move contacts, addresses, loans, and raw import rows into dedicated SQLAlchemy models. Update import and read paths so dashboard and API code continue to work using snapshot fields while preserving richer detail in related tables.

**Tech Stack:** FastAPI, SQLAlchemy ORM, Pydantic v2, manual migration scripts, MySQL-compatible schema conventions

---

## File Map

### Existing files to modify

- `backend/models/customer.py`
  Convert the current `Customer` model into the new lightweight snapshot model and add relationships to the new category tables.
- `backend/models/__init__.py`
  Export or import the new models if the package starts doing explicit imports later.
- `backend/core/database.py`
  Register the new models inside `init_db()` so `Base.metadata.create_all()` can create them.
- `backend/schemas/customer.py`
  Replace old shape fields like `name`, `address`, and `phone` with snapshot-friendly fields and nested relation responses where needed.
- `backend/controllers/api/customer_api.py`
  Update list/detail queries to use `full_name`, `primary_phone`, `current_loan_id`, and eager-loaded relations.
- `backend/controllers/dashboard/customer_controller.py`
  Update batch list, batch detail, upload mapping, and upload processing to populate the new schema.
- `backend/main.py`
  No logic changes expected, but this file is the smoke-test entry point after schema changes.
- `backend/requirements.txt`
  Add `pytest` so backend tests can run as part of the migration.

### New files to create

- `backend/models/customer_contact.py`
  Contact model for self, family, guarantor, office, and emergency channels.
- `backend/models/customer_address.py`
  Address model for home/office/billing/emergency data plus canonical and raw coordinates.
- `backend/models/customer_loan.py`
  Loan snapshot model for delinquency, outstanding, and payment/PTP metadata.
- `backend/models/customer_import_row.py`
  Raw import row model to preserve original Excel content and parse failures.
- `backend/scripts/migrate_customer_semi_normalized.py`
  Manual migration script that creates missing tables and adds new snapshot columns on `customers`.
- `backend/tests/test_customer_models.py`
  ORM-level tests for the new relationships and snapshot fields.
- `backend/tests/test_customer_upload_mapping.py`
  Upload-processing tests for row parsing into `Customer`, `CustomerLoan`, `CustomerAddress`, `CustomerContact`, and `CustomerImportRow`.

## Task 1: Add Backend Test Harness

**Files:**
- Modify: `backend/requirements.txt`
- Create: `backend/tests/test_customer_models.py`
- Create: `backend/tests/test_customer_upload_mapping.py`

- [ ] **Step 1: Add `pytest` to backend dependencies**

```txt
pytest==8.4.2
```

- [ ] **Step 2: Write the failing ORM relationship test**

```python
from decimal import Decimal

from models.customer import Customer
from models.customer_loan import CustomerLoan


def test_customer_can_hold_current_loan_snapshot():
    customer = Customer(
        full_name="Budi Santoso",
        platform_name="Partner A",
        status="new",
    )
    loan = CustomerLoan(
        customer=customer,
        is_current=1,
        loan_number="LN-001",
        total_outstanding=Decimal("1500000.00"),
        overdue_days=12,
    )

    customer.current_loan = loan
    customer.current_total_outstanding = loan.total_outstanding
    customer.current_dpd = loan.overdue_days

    assert customer.current_loan.loan_number == "LN-001"
    assert customer.current_total_outstanding == Decimal("1500000.00")
    assert customer.current_dpd == 12
```

- [ ] **Step 3: Write the failing import-shape parsing test**

```python
def test_import_row_preserves_raw_lat_lng_and_snapshot_fields():
    row = {
        "Nama": "Siti Aminah",
        "No HP": "08123456789",
        "Alamat": "Jl. Mawar No. 7",
        "Loan Number": "P2P-009",
        "OS": "1500000",
        "DPD": "18",
        "Lat&Lng": "-6.2,106.8",
    }

    result = build_customer_import_payload(
        row=row,
        mapping={
            "full_name": "Nama",
            "primary_phone": "No HP",
            "full_address": "Alamat",
            "loan_number": "Loan Number",
            "total_outstanding": "OS",
            "overdue_days": "DPD",
            "raw_lat_lng": "Lat&Lng",
        },
        batch_code="UPLOAD_20260416_100000",
    )

    assert result.customer.full_name == "Siti Aminah"
    assert result.customer.primary_phone == "08123456789"
    assert result.loan.loan_number == "P2P-009"
    assert str(result.loan.total_outstanding) == "1500000"
    assert result.loan.overdue_days == 18
    assert result.address.raw_lat_lng == "-6.2,106.8"
    assert result.import_row.raw_payload["Lat&Lng"] == "-6.2,106.8"
```

- [ ] **Step 4: Run tests to verify they fail before implementation**

Run:

```bash
cd backend
venv\Scripts\python -m pytest backend/tests/test_customer_models.py backend/tests/test_customer_upload_mapping.py -q
```

Expected:

```txt
E   ModuleNotFoundError: No module named 'models.customer_loan'
E   NameError: name 'build_customer_import_payload' is not defined
```

- [ ] **Step 5: Commit the failing test harness**

```bash
git add backend/requirements.txt backend/tests/test_customer_models.py backend/tests/test_customer_upload_mapping.py
git commit -m "test: add customer semi-normalized backend coverage"
```

## Task 2: Add Semi-Normalized ORM Models

**Files:**
- Modify: `backend/models/customer.py`
- Create: `backend/models/customer_contact.py`
- Create: `backend/models/customer_address.py`
- Create: `backend/models/customer_loan.py`
- Create: `backend/models/customer_import_row.py`
- Modify: `backend/core/database.py`
- Test: `backend/tests/test_customer_models.py`

- [ ] **Step 1: Replace the old `Customer` shape with snapshot-focused fields**

```python
from sqlalchemy import Column, Date, DateTime, ForeignKey, Integer, Numeric, String, Text, func
from sqlalchemy.orm import relationship


class Customer(Base):
    __tablename__ = "customers"

    id = Column(Integer, primary_key=True, autoincrement=True)
    full_name = Column(String(255), nullable=False, index=True)
    nick_name = Column(String(100), nullable=True)
    customer_code = Column(String(100), nullable=True, index=True)
    external_customer_id = Column(String(100), nullable=True, index=True)
    platform_name = Column(String(100), nullable=True, index=True)
    partner_name = Column(String(100), nullable=True)
    nik = Column(String(50), nullable=True, index=True)
    birth_date = Column(Date, nullable=True)
    gender = Column(String(20), nullable=True)
    email = Column(String(255), nullable=True)
    primary_phone = Column(String(50), nullable=True)
    primary_city = Column(String(100), nullable=True)
    primary_address_summary = Column(Text, nullable=True)
    assigned_agent_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    status = Column(String(30), nullable=False, default="new", index=True)
    sub_status = Column(String(50), nullable=True, index=True)
    current_loan_id = Column(Integer, ForeignKey("customer_loans.id"), nullable=True, index=True)
    current_dpd = Column(Integer, nullable=True, index=True)
    current_total_outstanding = Column(Numeric(18, 2), nullable=True)
    last_payment_date = Column(Date, nullable=True)
    last_payment_amount = Column(Numeric(18, 2), nullable=True)
    last_contacted_at = Column(DateTime, nullable=True)
    upload_batch = Column(String(100), nullable=True, index=True)
    search_name = Column(String(255), nullable=True, index=True)
    search_nik = Column(String(50), nullable=True, index=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
    is_deleted = Column(Integer, default=0, index=True)
```

- [ ] **Step 2: Create the category models with focused responsibilities**

```python
class CustomerContact(Base):
    __tablename__ = "customer_contacts"

    id = Column(Integer, primary_key=True, autoincrement=True)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=False, index=True)
    contact_type = Column(String(30), nullable=False, index=True)
    contact_role = Column(String(30), nullable=False, index=True)
    name = Column(String(255), nullable=True)
    relationship = Column(String(100), nullable=True)
    phone_number = Column(String(50), nullable=True, index=True)
    email = Column(String(255), nullable=True)
    is_primary = Column(Integer, default=0, index=True)
```

```python
class CustomerAddress(Base):
    __tablename__ = "customer_addresses"

    id = Column(Integer, primary_key=True, autoincrement=True)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=False, index=True)
    address_type = Column(String(30), nullable=False, index=True)
    full_address = Column(Text, nullable=False)
    city = Column(String(100), nullable=True, index=True)
    province = Column(String(100), nullable=True, index=True)
    lat = Column(Float, nullable=True)
    lng = Column(Float, nullable=True)
    raw_lat_lng = Column(String(255), nullable=True)
    is_primary = Column(Integer, default=0, index=True)
```

```python
class CustomerLoan(Base):
    __tablename__ = "customer_loans"

    id = Column(Integer, primary_key=True, autoincrement=True)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=False, index=True)
    is_current = Column(Integer, default=0, index=True)
    application_id = Column(String(100), nullable=True, index=True)
    loan_number = Column(String(100), nullable=True, index=True)
    contract_number = Column(String(100), nullable=True, index=True)
    platform_name = Column(String(100), nullable=True, index=True)
    due_date = Column(Date, nullable=True, index=True)
    loan_amount = Column(Numeric(18, 2), nullable=True)
    installment_amount = Column(Numeric(18, 2), nullable=True)
    total_outstanding = Column(Numeric(18, 2), nullable=True)
    overdue_days = Column(Integer, nullable=True, index=True)
```

```python
class CustomerImportRow(Base):
    __tablename__ = "customer_import_rows"

    id = Column(Integer, primary_key=True, autoincrement=True)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=True, index=True)
    upload_batch = Column(String(100), nullable=False, index=True)
    source_partner_name = Column(String(100), nullable=True, index=True)
    source_file_name = Column(String(255), nullable=True, index=True)
    source_sheet_name = Column(String(100), nullable=True)
    source_row_number = Column(Integer, nullable=True, index=True)
    import_status = Column(String(30), nullable=False, default="imported", index=True)
    import_error_flag = Column(Integer, default=0, index=True)
    raw_customer_name = Column(String(255), nullable=True)
    raw_phone = Column(String(50), nullable=True)
    raw_address = Column(Text, nullable=True)
    raw_due_date = Column(String(100), nullable=True)
    raw_outstanding_amount = Column(String(100), nullable=True)
    raw_lat_lng = Column(String(255), nullable=True)
    raw_payload = Column(Text, nullable=True)
```

- [ ] **Step 3: Wire relationships and database registration**

```python
# backend/models/customer.py
    agent = relationship("User", back_populates="assigned_customers", foreign_keys=[assigned_agent_id])
    current_loan = relationship("CustomerLoan", foreign_keys=[current_loan_id], post_update=True)
    contacts = relationship("CustomerContact", back_populates="customer", cascade="all, delete-orphan")
    addresses = relationship("CustomerAddress", back_populates="customer", cascade="all, delete-orphan")
    loans = relationship("CustomerLoan", back_populates="customer", foreign_keys="CustomerLoan.customer_id", cascade="all, delete-orphan")
    import_rows = relationship("CustomerImportRow", back_populates="customer", cascade="all, delete-orphan")
```

```python
# backend/core/database.py
from models import (
    activity_log,
    collection,
    customer,
    customer_address,
    customer_contact,
    customer_import_row,
    customer_loan,
    user,
    va_data,
    va_request,
)
```

- [ ] **Step 4: Run ORM relationship tests until they pass**

Run:

```bash
cd backend
venv\Scripts\python -m pytest backend/tests/test_customer_models.py -q
```

Expected:

```txt
1 passed
```

- [ ] **Step 5: Commit the new ORM layer**

```bash
git add backend/models/customer.py backend/models/customer_contact.py backend/models/customer_address.py backend/models/customer_loan.py backend/models/customer_import_row.py backend/core/database.py
git commit -m "feat: add semi-normalized customer models"
```

## Task 3: Add a Safe Migration Script for Existing Databases

**Files:**
- Create: `backend/scripts/migrate_customer_semi_normalized.py`
- Modify: `backend/models/__init__.py`
- Test: `backend/tests/test_customer_models.py`

- [ ] **Step 1: Write the failing migration smoke check**

```python
def test_customer_model_has_snapshot_columns():
    columns = {column.name for column in Customer.__table__.columns}

    assert "full_name" in columns
    assert "primary_phone" in columns
    assert "current_loan_id" in columns
    assert "current_total_outstanding" in columns
```

- [ ] **Step 2: Create the migration script following the existing script style**

```python
from sqlalchemy import text

from core.database import Base, engine


SNAPSHOT_COLUMNS = [
    "full_name VARCHAR(255)",
    "nick_name VARCHAR(100)",
    "customer_code VARCHAR(100)",
    "external_customer_id VARCHAR(100)",
    "primary_phone VARCHAR(50)",
    "primary_city VARCHAR(100)",
    "primary_address_summary TEXT",
    "sub_status VARCHAR(50)",
    "current_loan_id INTEGER",
    "current_dpd INTEGER",
    "current_total_outstanding NUMERIC(18,2)",
    "last_payment_date DATE",
    "last_payment_amount NUMERIC(18,2)",
    "last_contacted_at DATETIME",
    "search_name VARCHAR(255)",
    "search_nik VARCHAR(50)",
]


def add_missing_customer_columns(conn):
    for column_sql in SNAPSHOT_COLUMNS:
        try:
            conn.execute(text(f"ALTER TABLE customers ADD COLUMN {column_sql}"))
            print(f"[OK] Added column: {column_sql}")
        except Exception:
            print(f"[SKIP] {column_sql}")


def migrate():
    from models import customer_address, customer_contact, customer_import_row, customer_loan  # noqa

    Base.metadata.create_all(engine, checkfirst=True)
    with engine.begin() as conn:
        add_missing_customer_columns(conn)
```

- [ ] **Step 3: Run the migration script against the local database**

Run:

```bash
cd backend
venv\Scripts\python scripts\migrate_customer_semi_normalized.py
```

Expected:

```txt
[OK] Added column: full_name VARCHAR(255)
[SKIP] current_loan_id INTEGER
Migration finished.
```

- [ ] **Step 4: Re-run ORM tests after migration**

Run:

```bash
cd backend
venv\Scripts\python -m pytest backend/tests/test_customer_models.py -q
```

Expected:

```txt
2 passed
```

- [ ] **Step 5: Commit the migration layer**

```bash
git add backend/scripts/migrate_customer_semi_normalized.py backend/models/__init__.py backend/tests/test_customer_models.py
git commit -m "feat: add customer semi-normalized migration script"
```

## Task 4: Update Customer Schemas and API Responses

**Files:**
- Modify: `backend/schemas/customer.py`
- Modify: `backend/controllers/api/customer_api.py`
- Test: `backend/tests/test_customer_models.py`

- [ ] **Step 1: Rewrite response schemas around snapshot fields**

```python
class CustomerResponse(BaseModel):
    id: int
    full_name: str
    primary_phone: Optional[str] = None
    primary_city: Optional[str] = None
    primary_address_summary: Optional[str] = None
    platform_name: Optional[str] = None
    status: str
    sub_status: Optional[str] = None
    current_dpd: Optional[int] = None
    current_total_outstanding: Optional[Decimal] = None
    assigned_agent_id: Optional[int] = None
    created_at: Optional[datetime] = None
```

```python
class CustomerLoanBriefResponse(BaseModel):
    id: int
    loan_number: Optional[str] = None
    contract_number: Optional[str] = None
    total_outstanding: Optional[Decimal] = None
    overdue_days: Optional[int] = None
```

```python
class CustomerDetailResponse(CustomerResponse):
    agent_name: Optional[str] = None
    current_loan: Optional[CustomerLoanBriefResponse] = None
    contacts: List[CustomerContactResponse] = []
    addresses: List[CustomerAddressResponse] = []
    collections: List["CollectionBriefResponse"] = []
```

- [ ] **Step 2: Update the list API query to search new snapshot fields**

```python
if search:
    search_filter = f"%{search}%"
    list_query = list_query.filter(
        or_(
            Customer.full_name.ilike(search_filter),
            Customer.primary_phone.ilike(search_filter),
            Customer.customer_code.ilike(search_filter),
        )
    )

order_stmt.append(Customer.full_name.asc())
```

- [ ] **Step 3: Update the detail API to eager-load current loan, contacts, and addresses**

```python
from sqlalchemy.orm import joinedload, selectinload

customer = (
    db.query(Customer)
    .options(
        joinedload(Customer.agent),
        joinedload(Customer.current_loan),
        selectinload(Customer.contacts),
        selectinload(Customer.addresses),
        selectinload(Customer.collections),
    )
    .filter(Customer.id == customer_id, Customer.assigned_agent_id == user.id, Customer.is_deleted == 0)
    .first()
)
```

- [ ] **Step 4: Add API regression assertions**

```python
def test_customer_response_uses_snapshot_fields():
    payload = CustomerResponse.model_validate(
        Customer(
            full_name="Budi",
            primary_phone="08123",
            status="active",
            current_dpd=5,
        )
    )

    assert payload.full_name == "Budi"
    assert payload.primary_phone == "08123"
    assert payload.current_dpd == 5
```

- [ ] **Step 5: Run schema and API tests, then commit**

Run:

```bash
cd backend
venv\Scripts\python -m pytest backend/tests/test_customer_models.py -q
```

Expected:

```txt
3 passed
```

Commit:

```bash
git add backend/schemas/customer.py backend/controllers/api/customer_api.py backend/tests/test_customer_models.py
git commit -m "feat: update customer api for semi-normalized schema"
```

## Task 5: Update Dashboard Upload Flow to Populate New Tables

**Files:**
- Modify: `backend/controllers/dashboard/customer_controller.py`
- Modify: `backend/models/customer.py`
- Modify: `backend/models/customer_contact.py`
- Modify: `backend/models/customer_address.py`
- Modify: `backend/models/customer_loan.py`
- Modify: `backend/models/customer_import_row.py`
- Test: `backend/tests/test_customer_upload_mapping.py`

- [ ] **Step 1: Expand the upload mapping UI field keys to the new schema**

```python
expected_fields = [
    {"key": "full_name", "label": "Nama (Wajib)", "required": True},
    {"key": "primary_phone", "label": "No. HP Utama", "required": False},
    {"key": "full_address", "label": "Alamat Utama", "required": False},
    {"key": "city", "label": "Kota", "required": False},
    {"key": "loan_number", "label": "Nomor Kontrak / Loan Number", "required": False},
    {"key": "platform_name", "label": "Platform / Aplikasi", "required": False},
    {"key": "total_outstanding", "label": "Outstanding Amount", "required": False},
    {"key": "overdue_days", "label": "Overdue (DPD)", "required": False},
    {"key": "due_date", "label": "Tanggal Jatuh Tempo", "required": False},
    {"key": "raw_lat_lng", "label": "Latitude & Longitude Gabungan", "required": False},
    {"key": "lat", "label": "Latitude (GPS)", "required": False},
    {"key": "lng", "label": "Longitude (GPS)", "required": False},
    {"key": "emergency_contact_name", "label": "Emergency Contact Name", "required": False},
    {"key": "emergency_contact_phone", "label": "Emergency Contact Phone", "required": False},
]
```

- [ ] **Step 2: Introduce a helper that builds normalized objects from one Excel row**

```python
def build_customer_import_payload(row, mapping, batch_code):
    full_name = clean_string(get_val(row, mapping, "full_name"))
    primary_phone = clean_string(get_val(row, mapping, "primary_phone"))
    full_address = clean_string(get_val(row, mapping, "full_address"))
    platform_name = clean_string(get_val(row, mapping, "platform_name"))
    raw_lat_lng = clean_string(get_val(row, mapping, "raw_lat_lng"))

    customer = Customer(
        full_name=full_name,
        primary_phone=primary_phone,
        primary_address_summary=full_address,
        primary_city=clean_string(get_val(row, mapping, "city")),
        platform_name=platform_name,
        status="new",
        upload_batch=batch_code,
        search_name=normalize_text(full_name),
    )
```

```python
    loan = CustomerLoan(
        is_current=1,
        loan_number=clean_string(get_val(row, mapping, "loan_number")),
        platform_name=platform_name,
        total_outstanding=parse_decimal(get_val(row, mapping, "total_outstanding")),
        overdue_days=parse_int(get_val(row, mapping, "overdue_days")),
        due_date=parse_date(get_val(row, mapping, "due_date")),
    )
```

```python
    address = CustomerAddress(
        address_type="home",
        full_address=full_address or "-",
        city=clean_string(get_val(row, mapping, "city")),
        lat=parse_float(get_val(row, mapping, "lat")),
        lng=parse_float(get_val(row, mapping, "lng")),
        raw_lat_lng=raw_lat_lng,
        is_primary=1,
    )
```

```python
    import_row = CustomerImportRow(
        upload_batch=batch_code,
        import_status="imported",
        raw_customer_name=full_name,
        raw_phone=primary_phone,
        raw_address=full_address,
        raw_due_date=stringify_value(get_val(row, mapping, "due_date")),
        raw_outstanding_amount=stringify_value(get_val(row, mapping, "total_outstanding")),
        raw_lat_lng=raw_lat_lng,
        raw_payload=json.dumps(row, ensure_ascii=True),
    )
```

- [ ] **Step 3: Persist related rows and sync snapshot fields during upload**

```python
payload = build_customer_import_payload(row=row_payload, mapping=mapping, batch_code=batch_code)
customer = payload.customer
db.add(customer)
db.flush()

payload.loan.customer_id = customer.id
db.add(payload.loan)
db.flush()

customer.current_loan_id = payload.loan.id
customer.current_dpd = payload.loan.overdue_days
customer.current_total_outstanding = payload.loan.total_outstanding

payload.address.customer_id = customer.id
db.add(payload.address)

if payload.contact:
    payload.contact.customer_id = customer.id
    db.add(payload.contact)

payload.import_row.customer_id = customer.id
db.add(payload.import_row)
```

- [ ] **Step 4: Run upload tests until they pass**

Run:

```bash
cd backend
venv\Scripts\python -m pytest backend/tests/test_customer_upload_mapping.py -q
```

Expected:

```txt
1 passed
```

- [ ] **Step 5: Commit the upload-path migration**

```bash
git add backend/controllers/dashboard/customer_controller.py backend/models/customer.py backend/models/customer_contact.py backend/models/customer_address.py backend/models/customer_loan.py backend/models/customer_import_row.py backend/tests/test_customer_upload_mapping.py
git commit -m "feat: migrate customer upload flow to semi-normalized schema"
```

## Task 6: Run End-to-End Verification and Clean Up Compatibility Gaps

**Files:**
- Modify: `backend/controllers/dashboard/customer_controller.py`
- Modify: `backend/controllers/api/customer_api.py`
- Modify: `backend/schemas/customer.py`
- Test: `backend/tests/test_customer_models.py`
- Test: `backend/tests/test_customer_upload_mapping.py`

- [ ] **Step 1: Fix remaining old-field references**

Search for legacy fields and replace them:

```bash
rg "Customer\\.(name|phone|address|lat|lng|loan_number|outstanding_amount|due_date|overdue_days)" backend
```

Expected follow-up replacements:

```python
Customer.name -> Customer.full_name
Customer.phone -> Customer.primary_phone
Customer.address -> Customer.primary_address_summary
Customer.loan_number -> CustomerLoan.loan_number or Customer.current_loan.loan_number
```

- [ ] **Step 2: Run the full backend customer test suite**

Run:

```bash
cd backend
venv\Scripts\python -m pytest backend/tests/test_customer_models.py backend/tests/test_customer_upload_mapping.py -q
```

Expected:

```txt
4 passed
```

- [ ] **Step 3: Run the migration script one more time to confirm idempotency**

Run:

```bash
cd backend
venv\Scripts\python scripts\migrate_customer_semi_normalized.py
```

Expected:

```txt
[SKIP] full_name VARCHAR(255)
[SKIP] current_total_outstanding NUMERIC(18,2)
Migration finished.
```

- [ ] **Step 4: Run an application smoke test**

Run:

```bash
cd backend
venv\Scripts\python -c "from main import app; print(app.title)"
```

Expected:

```txt
Collection System P2P
```

- [ ] **Step 5: Commit the verification pass**

```bash
git add backend/controllers/dashboard/customer_controller.py backend/controllers/api/customer_api.py backend/schemas/customer.py backend/tests/test_customer_models.py backend/tests/test_customer_upload_mapping.py
git commit -m "chore: verify customer semi-normalized migration"
```

## Self-Review

### Spec coverage

- Lightweight `customers` snapshot model: covered in Task 2
- Dedicated contact, address, loan, and import-row tables: covered in Task 2
- Manual migration path for existing databases: covered in Task 3
- API and dashboard compatibility: covered in Tasks 4 and 5
- Excel compatibility and raw row preservation: covered in Task 5
- Verification and cleanup of legacy field references: covered in Task 6

### Placeholder scan

- No placeholder markers or deferred implementation notes remain
- Every code-changing step includes concrete code or command content
- Every verification step includes an exact command and expected result

### Type consistency

- Snapshot money fields consistently use `Numeric(18, 2)`
- Loan/source-of-truth data consistently lives in `CustomerLoan`
- Snapshot phone/address fields consistently live on `Customer`
- Raw import preservation consistently lives in `CustomerImportRow`
