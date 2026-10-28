// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalTransactionsTable extends LocalTransactions
    with TableInfo<$LocalTransactionsTable, LocalTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _userEmailMeta = const VerificationMeta(
    'userEmail',
  );
  @override
  late final GeneratedColumn<String> userEmail = GeneratedColumn<String>(
    'user_email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('marcos.pereira@gastosync.local'),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 255,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSyncedMeta = const VerificationMeta(
    'isSynced',
  );
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
    'is_synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userEmail,
    description,
    amount,
    date,
    type,
    category,
    isSynced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_email')) {
      context.handle(
        _userEmailMeta,
        userEmail.isAcceptableOrUnknown(data['user_email']!, _userEmailMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('is_synced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      userEmail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_email'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced'],
      )!,
    );
  }

  @override
  $LocalTransactionsTable createAlias(String alias) {
    return $LocalTransactionsTable(attachedDatabase, alias);
  }
}

class LocalTransaction extends DataClass
    implements Insertable<LocalTransaction> {
  final int id;
  final String userEmail;
  final String description;
  final double amount;
  final DateTime date;
  final String type;
  final String category;
  final bool isSynced;
  const LocalTransaction({
    required this.id,
    required this.userEmail,
    required this.description,
    required this.amount,
    required this.date,
    required this.type,
    required this.category,
    required this.isSynced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_email'] = Variable<String>(userEmail);
    map['description'] = Variable<String>(description);
    map['amount'] = Variable<double>(amount);
    map['date'] = Variable<DateTime>(date);
    map['type'] = Variable<String>(type);
    map['category'] = Variable<String>(category);
    map['is_synced'] = Variable<bool>(isSynced);
    return map;
  }

  LocalTransactionsCompanion toCompanion(bool nullToAbsent) {
    return LocalTransactionsCompanion(
      id: Value(id),
      userEmail: Value(userEmail),
      description: Value(description),
      amount: Value(amount),
      date: Value(date),
      type: Value(type),
      category: Value(category),
      isSynced: Value(isSynced),
    );
  }

  factory LocalTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTransaction(
      id: serializer.fromJson<int>(json['id']),
      userEmail: serializer.fromJson<String>(json['userEmail']),
      description: serializer.fromJson<String>(json['description']),
      amount: serializer.fromJson<double>(json['amount']),
      date: serializer.fromJson<DateTime>(json['date']),
      type: serializer.fromJson<String>(json['type']),
      category: serializer.fromJson<String>(json['category']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userEmail': serializer.toJson<String>(userEmail),
      'description': serializer.toJson<String>(description),
      'amount': serializer.toJson<double>(amount),
      'date': serializer.toJson<DateTime>(date),
      'type': serializer.toJson<String>(type),
      'category': serializer.toJson<String>(category),
      'isSynced': serializer.toJson<bool>(isSynced),
    };
  }

  LocalTransaction copyWith({
    int? id,
    String? userEmail,
    String? description,
    double? amount,
    DateTime? date,
    String? type,
    String? category,
    bool? isSynced,
  }) => LocalTransaction(
    id: id ?? this.id,
    userEmail: userEmail ?? this.userEmail,
    description: description ?? this.description,
    amount: amount ?? this.amount,
    date: date ?? this.date,
    type: type ?? this.type,
    category: category ?? this.category,
    isSynced: isSynced ?? this.isSynced,
  );
  LocalTransaction copyWithCompanion(LocalTransactionsCompanion data) {
    return LocalTransaction(
      id: data.id.present ? data.id.value : this.id,
      userEmail: data.userEmail.present ? data.userEmail.value : this.userEmail,
      description: data.description.present
          ? data.description.value
          : this.description,
      amount: data.amount.present ? data.amount.value : this.amount,
      date: data.date.present ? data.date.value : this.date,
      type: data.type.present ? data.type.value : this.type,
      category: data.category.present ? data.category.value : this.category,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransaction(')
          ..write('id: $id, ')
          ..write('userEmail: $userEmail, ')
          ..write('description: $description, ')
          ..write('amount: $amount, ')
          ..write('date: $date, ')
          ..write('type: $type, ')
          ..write('category: $category, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userEmail,
    description,
    amount,
    date,
    type,
    category,
    isSynced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTransaction &&
          other.id == this.id &&
          other.userEmail == this.userEmail &&
          other.description == this.description &&
          other.amount == this.amount &&
          other.date == this.date &&
          other.type == this.type &&
          other.category == this.category &&
          other.isSynced == this.isSynced);
}

class LocalTransactionsCompanion extends UpdateCompanion<LocalTransaction> {
  final Value<int> id;
  final Value<String> userEmail;
  final Value<String> description;
  final Value<double> amount;
  final Value<DateTime> date;
  final Value<String> type;
  final Value<String> category;
  final Value<bool> isSynced;
  const LocalTransactionsCompanion({
    this.id = const Value.absent(),
    this.userEmail = const Value.absent(),
    this.description = const Value.absent(),
    this.amount = const Value.absent(),
    this.date = const Value.absent(),
    this.type = const Value.absent(),
    this.category = const Value.absent(),
    this.isSynced = const Value.absent(),
  });
  LocalTransactionsCompanion.insert({
    this.id = const Value.absent(),
    this.userEmail = const Value.absent(),
    required String description,
    required double amount,
    required DateTime date,
    required String type,
    required String category,
    this.isSynced = const Value.absent(),
  }) : description = Value(description),
       amount = Value(amount),
       date = Value(date),
       type = Value(type),
       category = Value(category);
  static Insertable<LocalTransaction> custom({
    Expression<int>? id,
    Expression<String>? userEmail,
    Expression<String>? description,
    Expression<double>? amount,
    Expression<DateTime>? date,
    Expression<String>? type,
    Expression<String>? category,
    Expression<bool>? isSynced,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userEmail != null) 'user_email': userEmail,
      if (description != null) 'description': description,
      if (amount != null) 'amount': amount,
      if (date != null) 'date': date,
      if (type != null) 'type': type,
      if (category != null) 'category': category,
      if (isSynced != null) 'is_synced': isSynced,
    });
  }

  LocalTransactionsCompanion copyWith({
    Value<int>? id,
    Value<String>? userEmail,
    Value<String>? description,
    Value<double>? amount,
    Value<DateTime>? date,
    Value<String>? type,
    Value<String>? category,
    Value<bool>? isSynced,
  }) {
    return LocalTransactionsCompanion(
      id: id ?? this.id,
      userEmail: userEmail ?? this.userEmail,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userEmail.present) {
      map['user_email'] = Variable<String>(userEmail.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('userEmail: $userEmail, ')
          ..write('description: $description, ')
          ..write('amount: $amount, ')
          ..write('date: $date, ')
          ..write('type: $type, ')
          ..write('category: $category, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }
}

class $LocalBudgetsTable extends LocalBudgets
    with TableInfo<$LocalBudgetsTable, LocalBudget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalBudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _limitAmountMeta = const VerificationMeta(
    'limitAmount',
  );
  @override
  late final GeneratedColumn<double> limitAmount = GeneratedColumn<double>(
    'limit_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<int> month = GeneratedColumn<int>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    category,
    limitAmount,
    month,
    year,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalBudget> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('limit_amount')) {
      context.handle(
        _limitAmountMeta,
        limitAmount.isAcceptableOrUnknown(
          data['limit_amount']!,
          _limitAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_limitAmountMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalBudget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalBudget(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      limitAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}limit_amount'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
    );
  }

  @override
  $LocalBudgetsTable createAlias(String alias) {
    return $LocalBudgetsTable(attachedDatabase, alias);
  }
}

class LocalBudget extends DataClass implements Insertable<LocalBudget> {
  final int id;
  final String category;
  final double limitAmount;
  final int month;
  final int year;
  const LocalBudget({
    required this.id,
    required this.category,
    required this.limitAmount,
    required this.month,
    required this.year,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['category'] = Variable<String>(category);
    map['limit_amount'] = Variable<double>(limitAmount);
    map['month'] = Variable<int>(month);
    map['year'] = Variable<int>(year);
    return map;
  }

  LocalBudgetsCompanion toCompanion(bool nullToAbsent) {
    return LocalBudgetsCompanion(
      id: Value(id),
      category: Value(category),
      limitAmount: Value(limitAmount),
      month: Value(month),
      year: Value(year),
    );
  }

  factory LocalBudget.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalBudget(
      id: serializer.fromJson<int>(json['id']),
      category: serializer.fromJson<String>(json['category']),
      limitAmount: serializer.fromJson<double>(json['limitAmount']),
      month: serializer.fromJson<int>(json['month']),
      year: serializer.fromJson<int>(json['year']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'category': serializer.toJson<String>(category),
      'limitAmount': serializer.toJson<double>(limitAmount),
      'month': serializer.toJson<int>(month),
      'year': serializer.toJson<int>(year),
    };
  }

  LocalBudget copyWith({
    int? id,
    String? category,
    double? limitAmount,
    int? month,
    int? year,
  }) => LocalBudget(
    id: id ?? this.id,
    category: category ?? this.category,
    limitAmount: limitAmount ?? this.limitAmount,
    month: month ?? this.month,
    year: year ?? this.year,
  );
  LocalBudget copyWithCompanion(LocalBudgetsCompanion data) {
    return LocalBudget(
      id: data.id.present ? data.id.value : this.id,
      category: data.category.present ? data.category.value : this.category,
      limitAmount: data.limitAmount.present
          ? data.limitAmount.value
          : this.limitAmount,
      month: data.month.present ? data.month.value : this.month,
      year: data.year.present ? data.year.value : this.year,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalBudget(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('limitAmount: $limitAmount, ')
          ..write('month: $month, ')
          ..write('year: $year')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, category, limitAmount, month, year);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalBudget &&
          other.id == this.id &&
          other.category == this.category &&
          other.limitAmount == this.limitAmount &&
          other.month == this.month &&
          other.year == this.year);
}

class LocalBudgetsCompanion extends UpdateCompanion<LocalBudget> {
  final Value<int> id;
  final Value<String> category;
  final Value<double> limitAmount;
  final Value<int> month;
  final Value<int> year;
  const LocalBudgetsCompanion({
    this.id = const Value.absent(),
    this.category = const Value.absent(),
    this.limitAmount = const Value.absent(),
    this.month = const Value.absent(),
    this.year = const Value.absent(),
  });
  LocalBudgetsCompanion.insert({
    this.id = const Value.absent(),
    required String category,
    required double limitAmount,
    required int month,
    required int year,
  }) : category = Value(category),
       limitAmount = Value(limitAmount),
       month = Value(month),
       year = Value(year);
  static Insertable<LocalBudget> custom({
    Expression<int>? id,
    Expression<String>? category,
    Expression<double>? limitAmount,
    Expression<int>? month,
    Expression<int>? year,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (category != null) 'category': category,
      if (limitAmount != null) 'limit_amount': limitAmount,
      if (month != null) 'month': month,
      if (year != null) 'year': year,
    });
  }

  LocalBudgetsCompanion copyWith({
    Value<int>? id,
    Value<String>? category,
    Value<double>? limitAmount,
    Value<int>? month,
    Value<int>? year,
  }) {
    return LocalBudgetsCompanion(
      id: id ?? this.id,
      category: category ?? this.category,
      limitAmount: limitAmount ?? this.limitAmount,
      month: month ?? this.month,
      year: year ?? this.year,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (limitAmount.present) {
      map['limit_amount'] = Variable<double>(limitAmount.value);
    }
    if (month.present) {
      map['month'] = Variable<int>(month.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalBudgetsCompanion(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('limitAmount: $limitAmount, ')
          ..write('month: $month, ')
          ..write('year: $year')
          ..write(')'))
        .toString();
  }
}

class $LocalMetricsTable extends LocalMetrics
    with TableInfo<$LocalMetricsTable, LocalMetric> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMetricsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _calculatedAtMeta = const VerificationMeta(
    'calculatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> calculatedAt = GeneratedColumn<DateTime>(
    'calculated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentBalanceMeta = const VerificationMeta(
    'currentBalance',
  );
  @override
  late final GeneratedColumn<double> currentBalance = GeneratedColumn<double>(
    'current_balance',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalIncomeMeta = const VerificationMeta(
    'totalIncome',
  );
  @override
  late final GeneratedColumn<double> totalIncome = GeneratedColumn<double>(
    'total_income',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalExpenseMeta = const VerificationMeta(
    'totalExpense',
  );
  @override
  late final GeneratedColumn<double> totalExpense = GeneratedColumn<double>(
    'total_expense',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savingsRateMeta = const VerificationMeta(
    'savingsRate',
  );
  @override
  late final GeneratedColumn<double> savingsRate = GeneratedColumn<double>(
    'savings_rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emergencyMonthsMeta = const VerificationMeta(
    'emergencyMonths',
  );
  @override
  late final GeneratedColumn<double> emergencyMonths = GeneratedColumn<double>(
    'emergency_months',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _incomeCommitmentMeta = const VerificationMeta(
    'incomeCommitment',
  );
  @override
  late final GeneratedColumn<double> incomeCommitment = GeneratedColumn<double>(
    'income_commitment',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dailyBurnRateMeta = const VerificationMeta(
    'dailyBurnRate',
  );
  @override
  late final GeneratedColumn<double> dailyBurnRate = GeneratedColumn<double>(
    'daily_burn_rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthEndProjectionMeta =
      const VerificationMeta('monthEndProjection');
  @override
  late final GeneratedColumn<double> monthEndProjection =
      GeneratedColumn<double>(
        'month_end_projection',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _healthScoreMeta = const VerificationMeta(
    'healthScore',
  );
  @override
  late final GeneratedColumn<double> healthScore = GeneratedColumn<double>(
    'health_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    calculatedAt,
    currentBalance,
    totalIncome,
    totalExpense,
    savingsRate,
    emergencyMonths,
    incomeCommitment,
    dailyBurnRate,
    monthEndProjection,
    healthScore,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_metrics';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMetric> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('calculated_at')) {
      context.handle(
        _calculatedAtMeta,
        calculatedAt.isAcceptableOrUnknown(
          data['calculated_at']!,
          _calculatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_calculatedAtMeta);
    }
    if (data.containsKey('current_balance')) {
      context.handle(
        _currentBalanceMeta,
        currentBalance.isAcceptableOrUnknown(
          data['current_balance']!,
          _currentBalanceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentBalanceMeta);
    }
    if (data.containsKey('total_income')) {
      context.handle(
        _totalIncomeMeta,
        totalIncome.isAcceptableOrUnknown(
          data['total_income']!,
          _totalIncomeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalIncomeMeta);
    }
    if (data.containsKey('total_expense')) {
      context.handle(
        _totalExpenseMeta,
        totalExpense.isAcceptableOrUnknown(
          data['total_expense']!,
          _totalExpenseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalExpenseMeta);
    }
    if (data.containsKey('savings_rate')) {
      context.handle(
        _savingsRateMeta,
        savingsRate.isAcceptableOrUnknown(
          data['savings_rate']!,
          _savingsRateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_savingsRateMeta);
    }
    if (data.containsKey('emergency_months')) {
      context.handle(
        _emergencyMonthsMeta,
        emergencyMonths.isAcceptableOrUnknown(
          data['emergency_months']!,
          _emergencyMonthsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_emergencyMonthsMeta);
    }
    if (data.containsKey('income_commitment')) {
      context.handle(
        _incomeCommitmentMeta,
        incomeCommitment.isAcceptableOrUnknown(
          data['income_commitment']!,
          _incomeCommitmentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_incomeCommitmentMeta);
    }
    if (data.containsKey('daily_burn_rate')) {
      context.handle(
        _dailyBurnRateMeta,
        dailyBurnRate.isAcceptableOrUnknown(
          data['daily_burn_rate']!,
          _dailyBurnRateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dailyBurnRateMeta);
    }
    if (data.containsKey('month_end_projection')) {
      context.handle(
        _monthEndProjectionMeta,
        monthEndProjection.isAcceptableOrUnknown(
          data['month_end_projection']!,
          _monthEndProjectionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_monthEndProjectionMeta);
    }
    if (data.containsKey('health_score')) {
      context.handle(
        _healthScoreMeta,
        healthScore.isAcceptableOrUnknown(
          data['health_score']!,
          _healthScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_healthScoreMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalMetric map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMetric(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      calculatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}calculated_at'],
      )!,
      currentBalance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}current_balance'],
      )!,
      totalIncome: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_income'],
      )!,
      totalExpense: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_expense'],
      )!,
      savingsRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}savings_rate'],
      )!,
      emergencyMonths: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}emergency_months'],
      )!,
      incomeCommitment: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}income_commitment'],
      )!,
      dailyBurnRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}daily_burn_rate'],
      )!,
      monthEndProjection: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}month_end_projection'],
      )!,
      healthScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}health_score'],
      )!,
    );
  }

  @override
  $LocalMetricsTable createAlias(String alias) {
    return $LocalMetricsTable(attachedDatabase, alias);
  }
}

class LocalMetric extends DataClass implements Insertable<LocalMetric> {
  final int id;
  final DateTime calculatedAt;
  final double currentBalance;
  final double totalIncome;
  final double totalExpense;
  final double savingsRate;
  final double emergencyMonths;
  final double incomeCommitment;
  final double dailyBurnRate;
  final double monthEndProjection;
  final double healthScore;
  const LocalMetric({
    required this.id,
    required this.calculatedAt,
    required this.currentBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.savingsRate,
    required this.emergencyMonths,
    required this.incomeCommitment,
    required this.dailyBurnRate,
    required this.monthEndProjection,
    required this.healthScore,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['calculated_at'] = Variable<DateTime>(calculatedAt);
    map['current_balance'] = Variable<double>(currentBalance);
    map['total_income'] = Variable<double>(totalIncome);
    map['total_expense'] = Variable<double>(totalExpense);
    map['savings_rate'] = Variable<double>(savingsRate);
    map['emergency_months'] = Variable<double>(emergencyMonths);
    map['income_commitment'] = Variable<double>(incomeCommitment);
    map['daily_burn_rate'] = Variable<double>(dailyBurnRate);
    map['month_end_projection'] = Variable<double>(monthEndProjection);
    map['health_score'] = Variable<double>(healthScore);
    return map;
  }

  LocalMetricsCompanion toCompanion(bool nullToAbsent) {
    return LocalMetricsCompanion(
      id: Value(id),
      calculatedAt: Value(calculatedAt),
      currentBalance: Value(currentBalance),
      totalIncome: Value(totalIncome),
      totalExpense: Value(totalExpense),
      savingsRate: Value(savingsRate),
      emergencyMonths: Value(emergencyMonths),
      incomeCommitment: Value(incomeCommitment),
      dailyBurnRate: Value(dailyBurnRate),
      monthEndProjection: Value(monthEndProjection),
      healthScore: Value(healthScore),
    );
  }

  factory LocalMetric.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMetric(
      id: serializer.fromJson<int>(json['id']),
      calculatedAt: serializer.fromJson<DateTime>(json['calculatedAt']),
      currentBalance: serializer.fromJson<double>(json['currentBalance']),
      totalIncome: serializer.fromJson<double>(json['totalIncome']),
      totalExpense: serializer.fromJson<double>(json['totalExpense']),
      savingsRate: serializer.fromJson<double>(json['savingsRate']),
      emergencyMonths: serializer.fromJson<double>(json['emergencyMonths']),
      incomeCommitment: serializer.fromJson<double>(json['incomeCommitment']),
      dailyBurnRate: serializer.fromJson<double>(json['dailyBurnRate']),
      monthEndProjection: serializer.fromJson<double>(
        json['monthEndProjection'],
      ),
      healthScore: serializer.fromJson<double>(json['healthScore']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'calculatedAt': serializer.toJson<DateTime>(calculatedAt),
      'currentBalance': serializer.toJson<double>(currentBalance),
      'totalIncome': serializer.toJson<double>(totalIncome),
      'totalExpense': serializer.toJson<double>(totalExpense),
      'savingsRate': serializer.toJson<double>(savingsRate),
      'emergencyMonths': serializer.toJson<double>(emergencyMonths),
      'incomeCommitment': serializer.toJson<double>(incomeCommitment),
      'dailyBurnRate': serializer.toJson<double>(dailyBurnRate),
      'monthEndProjection': serializer.toJson<double>(monthEndProjection),
      'healthScore': serializer.toJson<double>(healthScore),
    };
  }

  LocalMetric copyWith({
    int? id,
    DateTime? calculatedAt,
    double? currentBalance,
    double? totalIncome,
    double? totalExpense,
    double? savingsRate,
    double? emergencyMonths,
    double? incomeCommitment,
    double? dailyBurnRate,
    double? monthEndProjection,
    double? healthScore,
  }) => LocalMetric(
    id: id ?? this.id,
    calculatedAt: calculatedAt ?? this.calculatedAt,
    currentBalance: currentBalance ?? this.currentBalance,
    totalIncome: totalIncome ?? this.totalIncome,
    totalExpense: totalExpense ?? this.totalExpense,
    savingsRate: savingsRate ?? this.savingsRate,
    emergencyMonths: emergencyMonths ?? this.emergencyMonths,
    incomeCommitment: incomeCommitment ?? this.incomeCommitment,
    dailyBurnRate: dailyBurnRate ?? this.dailyBurnRate,
    monthEndProjection: monthEndProjection ?? this.monthEndProjection,
    healthScore: healthScore ?? this.healthScore,
  );
  LocalMetric copyWithCompanion(LocalMetricsCompanion data) {
    return LocalMetric(
      id: data.id.present ? data.id.value : this.id,
      calculatedAt: data.calculatedAt.present
          ? data.calculatedAt.value
          : this.calculatedAt,
      currentBalance: data.currentBalance.present
          ? data.currentBalance.value
          : this.currentBalance,
      totalIncome: data.totalIncome.present
          ? data.totalIncome.value
          : this.totalIncome,
      totalExpense: data.totalExpense.present
          ? data.totalExpense.value
          : this.totalExpense,
      savingsRate: data.savingsRate.present
          ? data.savingsRate.value
          : this.savingsRate,
      emergencyMonths: data.emergencyMonths.present
          ? data.emergencyMonths.value
          : this.emergencyMonths,
      incomeCommitment: data.incomeCommitment.present
          ? data.incomeCommitment.value
          : this.incomeCommitment,
      dailyBurnRate: data.dailyBurnRate.present
          ? data.dailyBurnRate.value
          : this.dailyBurnRate,
      monthEndProjection: data.monthEndProjection.present
          ? data.monthEndProjection.value
          : this.monthEndProjection,
      healthScore: data.healthScore.present
          ? data.healthScore.value
          : this.healthScore,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMetric(')
          ..write('id: $id, ')
          ..write('calculatedAt: $calculatedAt, ')
          ..write('currentBalance: $currentBalance, ')
          ..write('totalIncome: $totalIncome, ')
          ..write('totalExpense: $totalExpense, ')
          ..write('savingsRate: $savingsRate, ')
          ..write('emergencyMonths: $emergencyMonths, ')
          ..write('incomeCommitment: $incomeCommitment, ')
          ..write('dailyBurnRate: $dailyBurnRate, ')
          ..write('monthEndProjection: $monthEndProjection, ')
          ..write('healthScore: $healthScore')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    calculatedAt,
    currentBalance,
    totalIncome,
    totalExpense,
    savingsRate,
    emergencyMonths,
    incomeCommitment,
    dailyBurnRate,
    monthEndProjection,
    healthScore,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMetric &&
          other.id == this.id &&
          other.calculatedAt == this.calculatedAt &&
          other.currentBalance == this.currentBalance &&
          other.totalIncome == this.totalIncome &&
          other.totalExpense == this.totalExpense &&
          other.savingsRate == this.savingsRate &&
          other.emergencyMonths == this.emergencyMonths &&
          other.incomeCommitment == this.incomeCommitment &&
          other.dailyBurnRate == this.dailyBurnRate &&
          other.monthEndProjection == this.monthEndProjection &&
          other.healthScore == this.healthScore);
}

class LocalMetricsCompanion extends UpdateCompanion<LocalMetric> {
  final Value<int> id;
  final Value<DateTime> calculatedAt;
  final Value<double> currentBalance;
  final Value<double> totalIncome;
  final Value<double> totalExpense;
  final Value<double> savingsRate;
  final Value<double> emergencyMonths;
  final Value<double> incomeCommitment;
  final Value<double> dailyBurnRate;
  final Value<double> monthEndProjection;
  final Value<double> healthScore;
  const LocalMetricsCompanion({
    this.id = const Value.absent(),
    this.calculatedAt = const Value.absent(),
    this.currentBalance = const Value.absent(),
    this.totalIncome = const Value.absent(),
    this.totalExpense = const Value.absent(),
    this.savingsRate = const Value.absent(),
    this.emergencyMonths = const Value.absent(),
    this.incomeCommitment = const Value.absent(),
    this.dailyBurnRate = const Value.absent(),
    this.monthEndProjection = const Value.absent(),
    this.healthScore = const Value.absent(),
  });
  LocalMetricsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime calculatedAt,
    required double currentBalance,
    required double totalIncome,
    required double totalExpense,
    required double savingsRate,
    required double emergencyMonths,
    required double incomeCommitment,
    required double dailyBurnRate,
    required double monthEndProjection,
    required double healthScore,
  }) : calculatedAt = Value(calculatedAt),
       currentBalance = Value(currentBalance),
       totalIncome = Value(totalIncome),
       totalExpense = Value(totalExpense),
       savingsRate = Value(savingsRate),
       emergencyMonths = Value(emergencyMonths),
       incomeCommitment = Value(incomeCommitment),
       dailyBurnRate = Value(dailyBurnRate),
       monthEndProjection = Value(monthEndProjection),
       healthScore = Value(healthScore);
  static Insertable<LocalMetric> custom({
    Expression<int>? id,
    Expression<DateTime>? calculatedAt,
    Expression<double>? currentBalance,
    Expression<double>? totalIncome,
    Expression<double>? totalExpense,
    Expression<double>? savingsRate,
    Expression<double>? emergencyMonths,
    Expression<double>? incomeCommitment,
    Expression<double>? dailyBurnRate,
    Expression<double>? monthEndProjection,
    Expression<double>? healthScore,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (calculatedAt != null) 'calculated_at': calculatedAt,
      if (currentBalance != null) 'current_balance': currentBalance,
      if (totalIncome != null) 'total_income': totalIncome,
      if (totalExpense != null) 'total_expense': totalExpense,
      if (savingsRate != null) 'savings_rate': savingsRate,
      if (emergencyMonths != null) 'emergency_months': emergencyMonths,
      if (incomeCommitment != null) 'income_commitment': incomeCommitment,
      if (dailyBurnRate != null) 'daily_burn_rate': dailyBurnRate,
      if (monthEndProjection != null)
        'month_end_projection': monthEndProjection,
      if (healthScore != null) 'health_score': healthScore,
    });
  }

  LocalMetricsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? calculatedAt,
    Value<double>? currentBalance,
    Value<double>? totalIncome,
    Value<double>? totalExpense,
    Value<double>? savingsRate,
    Value<double>? emergencyMonths,
    Value<double>? incomeCommitment,
    Value<double>? dailyBurnRate,
    Value<double>? monthEndProjection,
    Value<double>? healthScore,
  }) {
    return LocalMetricsCompanion(
      id: id ?? this.id,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      currentBalance: currentBalance ?? this.currentBalance,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpense: totalExpense ?? this.totalExpense,
      savingsRate: savingsRate ?? this.savingsRate,
      emergencyMonths: emergencyMonths ?? this.emergencyMonths,
      incomeCommitment: incomeCommitment ?? this.incomeCommitment,
      dailyBurnRate: dailyBurnRate ?? this.dailyBurnRate,
      monthEndProjection: monthEndProjection ?? this.monthEndProjection,
      healthScore: healthScore ?? this.healthScore,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (calculatedAt.present) {
      map['calculated_at'] = Variable<DateTime>(calculatedAt.value);
    }
    if (currentBalance.present) {
      map['current_balance'] = Variable<double>(currentBalance.value);
    }
    if (totalIncome.present) {
      map['total_income'] = Variable<double>(totalIncome.value);
    }
    if (totalExpense.present) {
      map['total_expense'] = Variable<double>(totalExpense.value);
    }
    if (savingsRate.present) {
      map['savings_rate'] = Variable<double>(savingsRate.value);
    }
    if (emergencyMonths.present) {
      map['emergency_months'] = Variable<double>(emergencyMonths.value);
    }
    if (incomeCommitment.present) {
      map['income_commitment'] = Variable<double>(incomeCommitment.value);
    }
    if (dailyBurnRate.present) {
      map['daily_burn_rate'] = Variable<double>(dailyBurnRate.value);
    }
    if (monthEndProjection.present) {
      map['month_end_projection'] = Variable<double>(monthEndProjection.value);
    }
    if (healthScore.present) {
      map['health_score'] = Variable<double>(healthScore.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMetricsCompanion(')
          ..write('id: $id, ')
          ..write('calculatedAt: $calculatedAt, ')
          ..write('currentBalance: $currentBalance, ')
          ..write('totalIncome: $totalIncome, ')
          ..write('totalExpense: $totalExpense, ')
          ..write('savingsRate: $savingsRate, ')
          ..write('emergencyMonths: $emergencyMonths, ')
          ..write('incomeCommitment: $incomeCommitment, ')
          ..write('dailyBurnRate: $dailyBurnRate, ')
          ..write('monthEndProjection: $monthEndProjection, ')
          ..write('healthScore: $healthScore')
          ..write(')'))
        .toString();
  }
}

class $LocalAgentInsightsTable extends LocalAgentInsights
    with TableInfo<$LocalAgentInsightsTable, LocalAgentInsight> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAgentInsightsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
    'transaction_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawSuggestionMeta = const VerificationMeta(
    'rawSuggestion',
  );
  @override
  late final GeneratedColumn<String> rawSuggestion = GeneratedColumn<String>(
    'raw_suggestion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confidenceScoreMeta = const VerificationMeta(
    'confidenceScore',
  );
  @override
  late final GeneratedColumn<double> confidenceScore = GeneratedColumn<double>(
    'confidence_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categorySuggestedMeta = const VerificationMeta(
    'categorySuggested',
  );
  @override
  late final GeneratedColumn<String> categorySuggested =
      GeneratedColumn<String>(
        'category_suggested',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _budgetTipMeta = const VerificationMeta(
    'budgetTip',
  );
  @override
  late final GeneratedColumn<String> budgetTip = GeneratedColumn<String>(
    'budget_tip',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    transactionId,
    rawSuggestion,
    confidenceScore,
    categorySuggested,
    budgetTip,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_agent_insights';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalAgentInsight> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    }
    if (data.containsKey('raw_suggestion')) {
      context.handle(
        _rawSuggestionMeta,
        rawSuggestion.isAcceptableOrUnknown(
          data['raw_suggestion']!,
          _rawSuggestionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rawSuggestionMeta);
    }
    if (data.containsKey('confidence_score')) {
      context.handle(
        _confidenceScoreMeta,
        confidenceScore.isAcceptableOrUnknown(
          data['confidence_score']!,
          _confidenceScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_confidenceScoreMeta);
    }
    if (data.containsKey('category_suggested')) {
      context.handle(
        _categorySuggestedMeta,
        categorySuggested.isAcceptableOrUnknown(
          data['category_suggested']!,
          _categorySuggestedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_categorySuggestedMeta);
    }
    if (data.containsKey('budget_tip')) {
      context.handle(
        _budgetTipMeta,
        budgetTip.isAcceptableOrUnknown(data['budget_tip']!, _budgetTipMeta),
      );
    } else if (isInserting) {
      context.missing(_budgetTipMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalAgentInsight map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAgentInsight(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transaction_id'],
      ),
      rawSuggestion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_suggestion'],
      )!,
      confidenceScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence_score'],
      )!,
      categorySuggested: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_suggested'],
      )!,
      budgetTip: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_tip'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalAgentInsightsTable createAlias(String alias) {
    return $LocalAgentInsightsTable(attachedDatabase, alias);
  }
}

class LocalAgentInsight extends DataClass
    implements Insertable<LocalAgentInsight> {
  final int id;
  final int? transactionId;
  final String rawSuggestion;
  final double confidenceScore;
  final String categorySuggested;
  final String budgetTip;
  final DateTime createdAt;
  const LocalAgentInsight({
    required this.id,
    this.transactionId,
    required this.rawSuggestion,
    required this.confidenceScore,
    required this.categorySuggested,
    required this.budgetTip,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<int>(transactionId);
    }
    map['raw_suggestion'] = Variable<String>(rawSuggestion);
    map['confidence_score'] = Variable<double>(confidenceScore);
    map['category_suggested'] = Variable<String>(categorySuggested);
    map['budget_tip'] = Variable<String>(budgetTip);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalAgentInsightsCompanion toCompanion(bool nullToAbsent) {
    return LocalAgentInsightsCompanion(
      id: Value(id),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
      rawSuggestion: Value(rawSuggestion),
      confidenceScore: Value(confidenceScore),
      categorySuggested: Value(categorySuggested),
      budgetTip: Value(budgetTip),
      createdAt: Value(createdAt),
    );
  }

  factory LocalAgentInsight.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAgentInsight(
      id: serializer.fromJson<int>(json['id']),
      transactionId: serializer.fromJson<int?>(json['transactionId']),
      rawSuggestion: serializer.fromJson<String>(json['rawSuggestion']),
      confidenceScore: serializer.fromJson<double>(json['confidenceScore']),
      categorySuggested: serializer.fromJson<String>(json['categorySuggested']),
      budgetTip: serializer.fromJson<String>(json['budgetTip']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'transactionId': serializer.toJson<int?>(transactionId),
      'rawSuggestion': serializer.toJson<String>(rawSuggestion),
      'confidenceScore': serializer.toJson<double>(confidenceScore),
      'categorySuggested': serializer.toJson<String>(categorySuggested),
      'budgetTip': serializer.toJson<String>(budgetTip),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalAgentInsight copyWith({
    int? id,
    Value<int?> transactionId = const Value.absent(),
    String? rawSuggestion,
    double? confidenceScore,
    String? categorySuggested,
    String? budgetTip,
    DateTime? createdAt,
  }) => LocalAgentInsight(
    id: id ?? this.id,
    transactionId: transactionId.present
        ? transactionId.value
        : this.transactionId,
    rawSuggestion: rawSuggestion ?? this.rawSuggestion,
    confidenceScore: confidenceScore ?? this.confidenceScore,
    categorySuggested: categorySuggested ?? this.categorySuggested,
    budgetTip: budgetTip ?? this.budgetTip,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalAgentInsight copyWithCompanion(LocalAgentInsightsCompanion data) {
    return LocalAgentInsight(
      id: data.id.present ? data.id.value : this.id,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      rawSuggestion: data.rawSuggestion.present
          ? data.rawSuggestion.value
          : this.rawSuggestion,
      confidenceScore: data.confidenceScore.present
          ? data.confidenceScore.value
          : this.confidenceScore,
      categorySuggested: data.categorySuggested.present
          ? data.categorySuggested.value
          : this.categorySuggested,
      budgetTip: data.budgetTip.present ? data.budgetTip.value : this.budgetTip,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAgentInsight(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('rawSuggestion: $rawSuggestion, ')
          ..write('confidenceScore: $confidenceScore, ')
          ..write('categorySuggested: $categorySuggested, ')
          ..write('budgetTip: $budgetTip, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    transactionId,
    rawSuggestion,
    confidenceScore,
    categorySuggested,
    budgetTip,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAgentInsight &&
          other.id == this.id &&
          other.transactionId == this.transactionId &&
          other.rawSuggestion == this.rawSuggestion &&
          other.confidenceScore == this.confidenceScore &&
          other.categorySuggested == this.categorySuggested &&
          other.budgetTip == this.budgetTip &&
          other.createdAt == this.createdAt);
}

class LocalAgentInsightsCompanion extends UpdateCompanion<LocalAgentInsight> {
  final Value<int> id;
  final Value<int?> transactionId;
  final Value<String> rawSuggestion;
  final Value<double> confidenceScore;
  final Value<String> categorySuggested;
  final Value<String> budgetTip;
  final Value<DateTime> createdAt;
  const LocalAgentInsightsCompanion({
    this.id = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.rawSuggestion = const Value.absent(),
    this.confidenceScore = const Value.absent(),
    this.categorySuggested = const Value.absent(),
    this.budgetTip = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LocalAgentInsightsCompanion.insert({
    this.id = const Value.absent(),
    this.transactionId = const Value.absent(),
    required String rawSuggestion,
    required double confidenceScore,
    required String categorySuggested,
    required String budgetTip,
    required DateTime createdAt,
  }) : rawSuggestion = Value(rawSuggestion),
       confidenceScore = Value(confidenceScore),
       categorySuggested = Value(categorySuggested),
       budgetTip = Value(budgetTip),
       createdAt = Value(createdAt);
  static Insertable<LocalAgentInsight> custom({
    Expression<int>? id,
    Expression<int>? transactionId,
    Expression<String>? rawSuggestion,
    Expression<double>? confidenceScore,
    Expression<String>? categorySuggested,
    Expression<String>? budgetTip,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transactionId != null) 'transaction_id': transactionId,
      if (rawSuggestion != null) 'raw_suggestion': rawSuggestion,
      if (confidenceScore != null) 'confidence_score': confidenceScore,
      if (categorySuggested != null) 'category_suggested': categorySuggested,
      if (budgetTip != null) 'budget_tip': budgetTip,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LocalAgentInsightsCompanion copyWith({
    Value<int>? id,
    Value<int?>? transactionId,
    Value<String>? rawSuggestion,
    Value<double>? confidenceScore,
    Value<String>? categorySuggested,
    Value<String>? budgetTip,
    Value<DateTime>? createdAt,
  }) {
    return LocalAgentInsightsCompanion(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      rawSuggestion: rawSuggestion ?? this.rawSuggestion,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      categorySuggested: categorySuggested ?? this.categorySuggested,
      budgetTip: budgetTip ?? this.budgetTip,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (rawSuggestion.present) {
      map['raw_suggestion'] = Variable<String>(rawSuggestion.value);
    }
    if (confidenceScore.present) {
      map['confidence_score'] = Variable<double>(confidenceScore.value);
    }
    if (categorySuggested.present) {
      map['category_suggested'] = Variable<String>(categorySuggested.value);
    }
    if (budgetTip.present) {
      map['budget_tip'] = Variable<String>(budgetTip.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAgentInsightsCompanion(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('rawSuggestion: $rawSuggestion, ')
          ..write('confidenceScore: $confidenceScore, ')
          ..write('categorySuggested: $categorySuggested, ')
          ..write('budgetTip: $budgetTip, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalTransactionsTable localTransactions =
      $LocalTransactionsTable(this);
  late final $LocalBudgetsTable localBudgets = $LocalBudgetsTable(this);
  late final $LocalMetricsTable localMetrics = $LocalMetricsTable(this);
  late final $LocalAgentInsightsTable localAgentInsights =
      $LocalAgentInsightsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localTransactions,
    localBudgets,
    localMetrics,
    localAgentInsights,
  ];
}

typedef $$LocalTransactionsTableCreateCompanionBuilder =
    LocalTransactionsCompanion Function({
      Value<int> id,
      Value<String> userEmail,
      required String description,
      required double amount,
      required DateTime date,
      required String type,
      required String category,
      Value<bool> isSynced,
    });
typedef $$LocalTransactionsTableUpdateCompanionBuilder =
    LocalTransactionsCompanion Function({
      Value<int> id,
      Value<String> userEmail,
      Value<String> description,
      Value<double> amount,
      Value<DateTime> date,
      Value<String> type,
      Value<String> category,
      Value<bool> isSynced,
    });

class $$LocalTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userEmail => $composableBuilder(
    column: $table.userEmail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userEmail => $composableBuilder(
    column: $table.userEmail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userEmail =>
      $composableBuilder(column: $table.userEmail, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);
}

class $$LocalTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalTransactionsTable,
          LocalTransaction,
          $$LocalTransactionsTableFilterComposer,
          $$LocalTransactionsTableOrderingComposer,
          $$LocalTransactionsTableAnnotationComposer,
          $$LocalTransactionsTableCreateCompanionBuilder,
          $$LocalTransactionsTableUpdateCompanionBuilder,
          (
            LocalTransaction,
            BaseReferences<
              _$AppDatabase,
              $LocalTransactionsTable,
              LocalTransaction
            >,
          ),
          LocalTransaction,
          PrefetchHooks Function()
        > {
  $$LocalTransactionsTableTableManager(
    _$AppDatabase db,
    $LocalTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> userEmail = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
              }) => LocalTransactionsCompanion(
                id: id,
                userEmail: userEmail,
                description: description,
                amount: amount,
                date: date,
                type: type,
                category: category,
                isSynced: isSynced,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> userEmail = const Value.absent(),
                required String description,
                required double amount,
                required DateTime date,
                required String type,
                required String category,
                Value<bool> isSynced = const Value.absent(),
              }) => LocalTransactionsCompanion.insert(
                id: id,
                userEmail: userEmail,
                description: description,
                amount: amount,
                date: date,
                type: type,
                category: category,
                isSynced: isSynced,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalTransactionsTable, LocalTransaction>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalTransactionsTable,
                    LocalTransaction
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalTransactionsTable,
      LocalTransaction,
      $$LocalTransactionsTableFilterComposer,
      $$LocalTransactionsTableOrderingComposer,
      $$LocalTransactionsTableAnnotationComposer,
      $$LocalTransactionsTableCreateCompanionBuilder,
      $$LocalTransactionsTableUpdateCompanionBuilder,
      (
        LocalTransaction,
        BaseReferences<
          _$AppDatabase,
          $LocalTransactionsTable,
          LocalTransaction
        >,
      ),
      LocalTransaction,
      PrefetchHooks Function()
    >;
typedef $$LocalBudgetsTableCreateCompanionBuilder =
    LocalBudgetsCompanion Function({
      Value<int> id,
      required String category,
      required double limitAmount,
      required int month,
      required int year,
    });
typedef $$LocalBudgetsTableUpdateCompanionBuilder =
    LocalBudgetsCompanion Function({
      Value<int> id,
      Value<String> category,
      Value<double> limitAmount,
      Value<int> month,
      Value<int> year,
    });

class $$LocalBudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalBudgetsTable> {
  $$LocalBudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get limitAmount => $composableBuilder(
    column: $table.limitAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalBudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalBudgetsTable> {
  $$LocalBudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get limitAmount => $composableBuilder(
    column: $table.limitAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalBudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalBudgetsTable> {
  $$LocalBudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<double> get limitAmount => $composableBuilder(
    column: $table.limitAmount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);
}

class $$LocalBudgetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalBudgetsTable,
          LocalBudget,
          $$LocalBudgetsTableFilterComposer,
          $$LocalBudgetsTableOrderingComposer,
          $$LocalBudgetsTableAnnotationComposer,
          $$LocalBudgetsTableCreateCompanionBuilder,
          $$LocalBudgetsTableUpdateCompanionBuilder,
          (
            LocalBudget,
            BaseReferences<_$AppDatabase, $LocalBudgetsTable, LocalBudget>,
          ),
          LocalBudget,
          PrefetchHooks Function()
        > {
  $$LocalBudgetsTableTableManager(_$AppDatabase db, $LocalBudgetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalBudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalBudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalBudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<double> limitAmount = const Value.absent(),
                Value<int> month = const Value.absent(),
                Value<int> year = const Value.absent(),
              }) => LocalBudgetsCompanion(
                id: id,
                category: category,
                limitAmount: limitAmount,
                month: month,
                year: year,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String category,
                required double limitAmount,
                required int month,
                required int year,
              }) => LocalBudgetsCompanion.insert(
                id: id,
                category: category,
                limitAmount: limitAmount,
                month: month,
                year: year,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalBudgetsTable, LocalBudget>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalBudgetsTable,
                    LocalBudget
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalBudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalBudgetsTable,
      LocalBudget,
      $$LocalBudgetsTableFilterComposer,
      $$LocalBudgetsTableOrderingComposer,
      $$LocalBudgetsTableAnnotationComposer,
      $$LocalBudgetsTableCreateCompanionBuilder,
      $$LocalBudgetsTableUpdateCompanionBuilder,
      (
        LocalBudget,
        BaseReferences<_$AppDatabase, $LocalBudgetsTable, LocalBudget>,
      ),
      LocalBudget,
      PrefetchHooks Function()
    >;
typedef $$LocalMetricsTableCreateCompanionBuilder =
    LocalMetricsCompanion Function({
      Value<int> id,
      required DateTime calculatedAt,
      required double currentBalance,
      required double totalIncome,
      required double totalExpense,
      required double savingsRate,
      required double emergencyMonths,
      required double incomeCommitment,
      required double dailyBurnRate,
      required double monthEndProjection,
      required double healthScore,
    });
typedef $$LocalMetricsTableUpdateCompanionBuilder =
    LocalMetricsCompanion Function({
      Value<int> id,
      Value<DateTime> calculatedAt,
      Value<double> currentBalance,
      Value<double> totalIncome,
      Value<double> totalExpense,
      Value<double> savingsRate,
      Value<double> emergencyMonths,
      Value<double> incomeCommitment,
      Value<double> dailyBurnRate,
      Value<double> monthEndProjection,
      Value<double> healthScore,
    });

class $$LocalMetricsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalMetricsTable> {
  $$LocalMetricsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get calculatedAt => $composableBuilder(
    column: $table.calculatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get currentBalance => $composableBuilder(
    column: $table.currentBalance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalIncome => $composableBuilder(
    column: $table.totalIncome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalExpense => $composableBuilder(
    column: $table.totalExpense,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get savingsRate => $composableBuilder(
    column: $table.savingsRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get emergencyMonths => $composableBuilder(
    column: $table.emergencyMonths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get incomeCommitment => $composableBuilder(
    column: $table.incomeCommitment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get dailyBurnRate => $composableBuilder(
    column: $table.dailyBurnRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get monthEndProjection => $composableBuilder(
    column: $table.monthEndProjection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get healthScore => $composableBuilder(
    column: $table.healthScore,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalMetricsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalMetricsTable> {
  $$LocalMetricsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get calculatedAt => $composableBuilder(
    column: $table.calculatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get currentBalance => $composableBuilder(
    column: $table.currentBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalIncome => $composableBuilder(
    column: $table.totalIncome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalExpense => $composableBuilder(
    column: $table.totalExpense,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get savingsRate => $composableBuilder(
    column: $table.savingsRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get emergencyMonths => $composableBuilder(
    column: $table.emergencyMonths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get incomeCommitment => $composableBuilder(
    column: $table.incomeCommitment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get dailyBurnRate => $composableBuilder(
    column: $table.dailyBurnRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get monthEndProjection => $composableBuilder(
    column: $table.monthEndProjection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get healthScore => $composableBuilder(
    column: $table.healthScore,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalMetricsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalMetricsTable> {
  $$LocalMetricsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get calculatedAt => $composableBuilder(
    column: $table.calculatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get currentBalance => $composableBuilder(
    column: $table.currentBalance,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalIncome => $composableBuilder(
    column: $table.totalIncome,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalExpense => $composableBuilder(
    column: $table.totalExpense,
    builder: (column) => column,
  );

  GeneratedColumn<double> get savingsRate => $composableBuilder(
    column: $table.savingsRate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get emergencyMonths => $composableBuilder(
    column: $table.emergencyMonths,
    builder: (column) => column,
  );

  GeneratedColumn<double> get incomeCommitment => $composableBuilder(
    column: $table.incomeCommitment,
    builder: (column) => column,
  );

  GeneratedColumn<double> get dailyBurnRate => $composableBuilder(
    column: $table.dailyBurnRate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get monthEndProjection => $composableBuilder(
    column: $table.monthEndProjection,
    builder: (column) => column,
  );

  GeneratedColumn<double> get healthScore => $composableBuilder(
    column: $table.healthScore,
    builder: (column) => column,
  );
}

class $$LocalMetricsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalMetricsTable,
          LocalMetric,
          $$LocalMetricsTableFilterComposer,
          $$LocalMetricsTableOrderingComposer,
          $$LocalMetricsTableAnnotationComposer,
          $$LocalMetricsTableCreateCompanionBuilder,
          $$LocalMetricsTableUpdateCompanionBuilder,
          (
            LocalMetric,
            BaseReferences<_$AppDatabase, $LocalMetricsTable, LocalMetric>,
          ),
          LocalMetric,
          PrefetchHooks Function()
        > {
  $$LocalMetricsTableTableManager(_$AppDatabase db, $LocalMetricsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMetricsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalMetricsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalMetricsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> calculatedAt = const Value.absent(),
                Value<double> currentBalance = const Value.absent(),
                Value<double> totalIncome = const Value.absent(),
                Value<double> totalExpense = const Value.absent(),
                Value<double> savingsRate = const Value.absent(),
                Value<double> emergencyMonths = const Value.absent(),
                Value<double> incomeCommitment = const Value.absent(),
                Value<double> dailyBurnRate = const Value.absent(),
                Value<double> monthEndProjection = const Value.absent(),
                Value<double> healthScore = const Value.absent(),
              }) => LocalMetricsCompanion(
                id: id,
                calculatedAt: calculatedAt,
                currentBalance: currentBalance,
                totalIncome: totalIncome,
                totalExpense: totalExpense,
                savingsRate: savingsRate,
                emergencyMonths: emergencyMonths,
                incomeCommitment: incomeCommitment,
                dailyBurnRate: dailyBurnRate,
                monthEndProjection: monthEndProjection,
                healthScore: healthScore,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime calculatedAt,
                required double currentBalance,
                required double totalIncome,
                required double totalExpense,
                required double savingsRate,
                required double emergencyMonths,
                required double incomeCommitment,
                required double dailyBurnRate,
                required double monthEndProjection,
                required double healthScore,
              }) => LocalMetricsCompanion.insert(
                id: id,
                calculatedAt: calculatedAt,
                currentBalance: currentBalance,
                totalIncome: totalIncome,
                totalExpense: totalExpense,
                savingsRate: savingsRate,
                emergencyMonths: emergencyMonths,
                incomeCommitment: incomeCommitment,
                dailyBurnRate: dailyBurnRate,
                monthEndProjection: monthEndProjection,
                healthScore: healthScore,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalMetricsTable, LocalMetric>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalMetricsTable,
                    LocalMetric
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalMetricsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalMetricsTable,
      LocalMetric,
      $$LocalMetricsTableFilterComposer,
      $$LocalMetricsTableOrderingComposer,
      $$LocalMetricsTableAnnotationComposer,
      $$LocalMetricsTableCreateCompanionBuilder,
      $$LocalMetricsTableUpdateCompanionBuilder,
      (
        LocalMetric,
        BaseReferences<_$AppDatabase, $LocalMetricsTable, LocalMetric>,
      ),
      LocalMetric,
      PrefetchHooks Function()
    >;
typedef $$LocalAgentInsightsTableCreateCompanionBuilder =
    LocalAgentInsightsCompanion Function({
      Value<int> id,
      Value<int?> transactionId,
      required String rawSuggestion,
      required double confidenceScore,
      required String categorySuggested,
      required String budgetTip,
      required DateTime createdAt,
    });
typedef $$LocalAgentInsightsTableUpdateCompanionBuilder =
    LocalAgentInsightsCompanion Function({
      Value<int> id,
      Value<int?> transactionId,
      Value<String> rawSuggestion,
      Value<double> confidenceScore,
      Value<String> categorySuggested,
      Value<String> budgetTip,
      Value<DateTime> createdAt,
    });

class $$LocalAgentInsightsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalAgentInsightsTable> {
  $$LocalAgentInsightsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawSuggestion => $composableBuilder(
    column: $table.rawSuggestion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categorySuggested => $composableBuilder(
    column: $table.categorySuggested,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get budgetTip => $composableBuilder(
    column: $table.budgetTip,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalAgentInsightsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalAgentInsightsTable> {
  $$LocalAgentInsightsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawSuggestion => $composableBuilder(
    column: $table.rawSuggestion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categorySuggested => $composableBuilder(
    column: $table.categorySuggested,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budgetTip => $composableBuilder(
    column: $table.budgetTip,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalAgentInsightsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalAgentInsightsTable> {
  $$LocalAgentInsightsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawSuggestion => $composableBuilder(
    column: $table.rawSuggestion,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categorySuggested => $composableBuilder(
    column: $table.categorySuggested,
    builder: (column) => column,
  );

  GeneratedColumn<String> get budgetTip =>
      $composableBuilder(column: $table.budgetTip, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalAgentInsightsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalAgentInsightsTable,
          LocalAgentInsight,
          $$LocalAgentInsightsTableFilterComposer,
          $$LocalAgentInsightsTableOrderingComposer,
          $$LocalAgentInsightsTableAnnotationComposer,
          $$LocalAgentInsightsTableCreateCompanionBuilder,
          $$LocalAgentInsightsTableUpdateCompanionBuilder,
          (
            LocalAgentInsight,
            BaseReferences<
              _$AppDatabase,
              $LocalAgentInsightsTable,
              LocalAgentInsight
            >,
          ),
          LocalAgentInsight,
          PrefetchHooks Function()
        > {
  $$LocalAgentInsightsTableTableManager(
    _$AppDatabase db,
    $LocalAgentInsightsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAgentInsightsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAgentInsightsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAgentInsightsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> transactionId = const Value.absent(),
                Value<String> rawSuggestion = const Value.absent(),
                Value<double> confidenceScore = const Value.absent(),
                Value<String> categorySuggested = const Value.absent(),
                Value<String> budgetTip = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LocalAgentInsightsCompanion(
                id: id,
                transactionId: transactionId,
                rawSuggestion: rawSuggestion,
                confidenceScore: confidenceScore,
                categorySuggested: categorySuggested,
                budgetTip: budgetTip,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> transactionId = const Value.absent(),
                required String rawSuggestion,
                required double confidenceScore,
                required String categorySuggested,
                required String budgetTip,
                required DateTime createdAt,
              }) => LocalAgentInsightsCompanion.insert(
                id: id,
                transactionId: transactionId,
                rawSuggestion: rawSuggestion,
                confidenceScore: confidenceScore,
                categorySuggested: categorySuggested,
                budgetTip: budgetTip,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalAgentInsightsTable, LocalAgentInsight>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalAgentInsightsTable,
                    LocalAgentInsight
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalAgentInsightsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalAgentInsightsTable,
      LocalAgentInsight,
      $$LocalAgentInsightsTableFilterComposer,
      $$LocalAgentInsightsTableOrderingComposer,
      $$LocalAgentInsightsTableAnnotationComposer,
      $$LocalAgentInsightsTableCreateCompanionBuilder,
      $$LocalAgentInsightsTableUpdateCompanionBuilder,
      (
        LocalAgentInsight,
        BaseReferences<
          _$AppDatabase,
          $LocalAgentInsightsTable,
          LocalAgentInsight
        >,
      ),
      LocalAgentInsight,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalTransactionsTableTableManager get localTransactions =>
      $$LocalTransactionsTableTableManager(_db, _db.localTransactions);
  $$LocalBudgetsTableTableManager get localBudgets =>
      $$LocalBudgetsTableTableManager(_db, _db.localBudgets);
  $$LocalMetricsTableTableManager get localMetrics =>
      $$LocalMetricsTableTableManager(_db, _db.localMetrics);
  $$LocalAgentInsightsTableTableManager get localAgentInsights =>
      $$LocalAgentInsightsTableTableManager(_db, _db.localAgentInsights);
}
