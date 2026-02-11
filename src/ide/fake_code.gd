extends RefCounted
class_name FakeCode

const SNIPPETS = [
	["func validate_auth_token(token: String) -> bool:", "    var decoded = jwt.decode(token)", "    if decoded.exp < Time.get_unix_time():", "        return false", "    return decoded.issuer == VALID_ISSUER"],
	["func process_payment(amount: float, currency: String):", "    var tx = PaymentGateway.create()", "    tx.set_amount(amount)", "    tx.set_currency(currency)", "    return tx.execute()"],
	["class UserRepository:", "    var _db: Database", "", "    func find_by_email(email: String) -> User:", "        var query = _db.prepare(\"SELECT * FROM users\")", "        query.bind(\"email\", email)", "        return query.fetch_one()"],
	["func setup_middleware(app: Application):", "    app.use(cors_handler)", "    app.use(rate_limiter(100, 60))", "    app.use(auth_middleware)", "    app.use(request_logger)"],
	["async func fetch_dashboard_data(user_id: int):", "    var tasks = await api.get(\"/tasks/\" + str(user_id))", "    var stats = await api.get(\"/stats/\" + str(user_id))", "    return { \"tasks\": tasks, \"stats\": stats }"],
	["func run_migration_003():", "    db.execute(\"ALTER TABLE users ADD COLUMN role TEXT\")", "    db.execute(\"UPDATE users SET role = 'member'\")", "    db.execute(\"CREATE INDEX idx_users_role ON users(role)\")"],
	["func calculate_invoice(hours: float, rate: float) -> Dictionary:", "    var subtotal = hours * rate", "    var tax = subtotal * 0.21", "    var total = subtotal + tax", "    return {\"subtotal\": subtotal, \"tax\": tax, \"total\": total}"],
]

static func get_random_snippet() -> Array:
	return SNIPPETS[randi() % SNIPPETS.size()]
