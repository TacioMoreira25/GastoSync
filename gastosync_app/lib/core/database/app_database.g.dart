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
  static const VerificationMeta _clientUuidMeta = const VerificationMeta(
    'clientUuid',
  );
  @override
  late final GeneratedColumn<String> clientUuid = GeneratedColumn<String>(
    'client_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PIX'),
  );
  static const VerificationMeta _creditCardUuidMeta = const VerificationMeta(
    'creditCardUuid',
  );
  @override
  late final GeneratedColumn<String> creditCardUuid = GeneratedColumn<String>(
    'credit_card_uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientUuid,
    userEmail,
    description,
    amount,
    date,
    type,
    category,
    paymentMethod,
    creditCardUuid,
    isSynced,
    updatedAt,
    deletedAt,
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
    if (data.containsKey('client_uuid')) {
      context.handle(
        _clientUuidMeta,
        clientUuid.isAcceptableOrUnknown(data['client_uuid']!, _clientUuidMeta),
      );
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
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    }
    if (data.containsKey('credit_card_uuid')) {
      context.handle(
        _creditCardUuidMeta,
        creditCardUuid.isAcceptableOrUnknown(
          data['credit_card_uuid']!,
          _creditCardUuidMeta,
        ),
      );
    }
    if (data.containsKey('is_synced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
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
      clientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_uuid'],
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
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      )!,
      creditCardUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credit_card_uuid'],
      ),
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
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
  final String clientUuid;
  final String userEmail;
  final String description;
  final double amount;
  final DateTime date;
  final String type;
  final String category;
  final String paymentMethod;
  final String? creditCardUuid;
  final bool isSynced;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  const LocalTransaction({
    required this.id,
    required this.clientUuid,
    required this.userEmail,
    required this.description,
    required this.amount,
    required this.date,
    required this.type,
    required this.category,
    required this.paymentMethod,
    this.creditCardUuid,
    required this.isSynced,
    this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_uuid'] = Variable<String>(clientUuid);
    map['user_email'] = Variable<String>(userEmail);
    map['description'] = Variable<String>(description);
    map['amount'] = Variable<double>(amount);
    map['date'] = Variable<DateTime>(date);
    map['type'] = Variable<String>(type);
    map['category'] = Variable<String>(category);
    map['payment_method'] = Variable<String>(paymentMethod);
    if (!nullToAbsent || creditCardUuid != null) {
      map['credit_card_uuid'] = Variable<String>(creditCardUuid);
    }
    map['is_synced'] = Variable<bool>(isSynced);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  LocalTransactionsCompanion toCompanion(bool nullToAbsent) {
    return LocalTransactionsCompanion(
      id: Value(id),
      clientUuid: Value(clientUuid),
      userEmail: Value(userEmail),
      description: Value(description),
      amount: Value(amount),
      date: Value(date),
      type: Value(type),
      category: Value(category),
      paymentMethod: Value(paymentMethod),
      creditCardUuid: creditCardUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(creditCardUuid),
      isSynced: Value(isSynced),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory LocalTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTransaction(
      id: serializer.fromJson<int>(json['id']),
      clientUuid: serializer.fromJson<String>(json['clientUuid']),
      userEmail: serializer.fromJson<String>(json['userEmail']),
      description: serializer.fromJson<String>(json['description']),
      amount: serializer.fromJson<double>(json['amount']),
      date: serializer.fromJson<DateTime>(json['date']),
      type: serializer.fromJson<String>(json['type']),
      category: serializer.fromJson<String>(json['category']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
      creditCardUuid: serializer.fromJson<String?>(json['creditCardUuid']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientUuid': serializer.toJson<String>(clientUuid),
      'userEmail': serializer.toJson<String>(userEmail),
      'description': serializer.toJson<String>(description),
      'amount': serializer.toJson<double>(amount),
      'date': serializer.toJson<DateTime>(date),
      'type': serializer.toJson<String>(type),
      'category': serializer.toJson<String>(category),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
      'creditCardUuid': serializer.toJson<String?>(creditCardUuid),
      'isSynced': serializer.toJson<bool>(isSynced),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  LocalTransaction copyWith({
    int? id,
    String? clientUuid,
    String? userEmail,
    String? description,
    double? amount,
    DateTime? date,
    String? type,
    String? category,
    String? paymentMethod,
    Value<String?> creditCardUuid = const Value.absent(),
    bool? isSynced,
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => LocalTransaction(
    id: id ?? this.id,
    clientUuid: clientUuid ?? this.clientUuid,
    userEmail: userEmail ?? this.userEmail,
    description: description ?? this.description,
    amount: amount ?? this.amount,
    date: date ?? this.date,
    type: type ?? this.type,
    category: category ?? this.category,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    creditCardUuid: creditCardUuid.present
        ? creditCardUuid.value
        : this.creditCardUuid,
    isSynced: isSynced ?? this.isSynced,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  LocalTransaction copyWithCompanion(LocalTransactionsCompanion data) {
    return LocalTransaction(
      id: data.id.present ? data.id.value : this.id,
      clientUuid: data.clientUuid.present
          ? data.clientUuid.value
          : this.clientUuid,
      userEmail: data.userEmail.present ? data.userEmail.value : this.userEmail,
      description: data.description.present
          ? data.description.value
          : this.description,
      amount: data.amount.present ? data.amount.value : this.amount,
      date: data.date.present ? data.date.value : this.date,
      type: data.type.present ? data.type.value : this.type,
      category: data.category.present ? data.category.value : this.category,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      creditCardUuid: data.creditCardUuid.present
          ? data.creditCardUuid.value
          : this.creditCardUuid,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransaction(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('userEmail: $userEmail, ')
          ..write('description: $description, ')
          ..write('amount: $amount, ')
          ..write('date: $date, ')
          ..write('type: $type, ')
          ..write('category: $category, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('creditCardUuid: $creditCardUuid, ')
          ..write('isSynced: $isSynced, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientUuid,
    userEmail,
    description,
    amount,
    date,
    type,
    category,
    paymentMethod,
    creditCardUuid,
    isSynced,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTransaction &&
          other.id == this.id &&
          other.clientUuid == this.clientUuid &&
          other.userEmail == this.userEmail &&
          other.description == this.description &&
          other.amount == this.amount &&
          other.date == this.date &&
          other.type == this.type &&
          other.category == this.category &&
          other.paymentMethod == this.paymentMethod &&
          other.creditCardUuid == this.creditCardUuid &&
          other.isSynced == this.isSynced &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class LocalTransactionsCompanion extends UpdateCompanion<LocalTransaction> {
  final Value<int> id;
  final Value<String> clientUuid;
  final Value<String> userEmail;
  final Value<String> description;
  final Value<double> amount;
  final Value<DateTime> date;
  final Value<String> type;
  final Value<String> category;
  final Value<String> paymentMethod;
  final Value<String?> creditCardUuid;
  final Value<bool> isSynced;
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> deletedAt;
  const LocalTransactionsCompanion({
    this.id = const Value.absent(),
    this.clientUuid = const Value.absent(),
    this.userEmail = const Value.absent(),
    this.description = const Value.absent(),
    this.amount = const Value.absent(),
    this.date = const Value.absent(),
    this.type = const Value.absent(),
    this.category = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.creditCardUuid = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  LocalTransactionsCompanion.insert({
    this.id = const Value.absent(),
    this.clientUuid = const Value.absent(),
    this.userEmail = const Value.absent(),
    required String description,
    required double amount,
    required DateTime date,
    required String type,
    required String category,
    this.paymentMethod = const Value.absent(),
    this.creditCardUuid = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : description = Value(description),
       amount = Value(amount),
       date = Value(date),
       type = Value(type),
       category = Value(category);
  static Insertable<LocalTransaction> custom({
    Expression<int>? id,
    Expression<String>? clientUuid,
    Expression<String>? userEmail,
    Expression<String>? description,
    Expression<double>? amount,
    Expression<DateTime>? date,
    Expression<String>? type,
    Expression<String>? category,
    Expression<String>? paymentMethod,
    Expression<String>? creditCardUuid,
    Expression<bool>? isSynced,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientUuid != null) 'client_uuid': clientUuid,
      if (userEmail != null) 'user_email': userEmail,
      if (description != null) 'description': description,
      if (amount != null) 'amount': amount,
      if (date != null) 'date': date,
      if (type != null) 'type': type,
      if (category != null) 'category': category,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (creditCardUuid != null) 'credit_card_uuid': creditCardUuid,
      if (isSynced != null) 'is_synced': isSynced,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  LocalTransactionsCompanion copyWith({
    Value<int>? id,
    Value<String>? clientUuid,
    Value<String>? userEmail,
    Value<String>? description,
    Value<double>? amount,
    Value<DateTime>? date,
    Value<String>? type,
    Value<String>? category,
    Value<String>? paymentMethod,
    Value<String?>? creditCardUuid,
    Value<bool>? isSynced,
    Value<DateTime?>? updatedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return LocalTransactionsCompanion(
      id: id ?? this.id,
      clientUuid: clientUuid ?? this.clientUuid,
      userEmail: userEmail ?? this.userEmail,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      creditCardUuid: creditCardUuid ?? this.creditCardUuid,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientUuid.present) {
      map['client_uuid'] = Variable<String>(clientUuid.value);
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
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (creditCardUuid.present) {
      map['credit_card_uuid'] = Variable<String>(creditCardUuid.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('userEmail: $userEmail, ')
          ..write('description: $description, ')
          ..write('amount: $amount, ')
          ..write('date: $date, ')
          ..write('type: $type, ')
          ..write('category: $category, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('creditCardUuid: $creditCardUuid, ')
          ..write('isSynced: $isSynced, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $LocalBillsTable extends LocalBills
    with TableInfo<$LocalBillsTable, LocalBill> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalBillsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _clientUuidMeta = const VerificationMeta(
    'clientUuid',
  );
  @override
  late final GeneratedColumn<String> clientUuid = GeneratedColumn<String>(
    'client_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isRecurringMeta = const VerificationMeta(
    'isRecurring',
  );
  @override
  late final GeneratedColumn<bool> isRecurring = GeneratedColumn<bool>(
    'is_recurring',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_recurring" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isCreditCardChargeMeta =
      const VerificationMeta('isCreditCardCharge');
  @override
  late final GeneratedColumn<bool> isCreditCardCharge = GeneratedColumn<bool>(
    'is_credit_card_charge',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_credit_card_charge" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _creditCardUuidMeta = const VerificationMeta(
    'creditCardUuid',
  );
  @override
  late final GeneratedColumn<String> creditCardUuid = GeneratedColumn<String>(
    'credit_card_uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _paidAtMeta = const VerificationMeta('paidAt');
  @override
  late final GeneratedColumn<DateTime> paidAt = GeneratedColumn<DateTime>(
    'paid_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedTransactionIdMeta =
      const VerificationMeta('linkedTransactionId');
  @override
  late final GeneratedColumn<int> linkedTransactionId = GeneratedColumn<int>(
    'linked_transaction_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedTxUuidMeta = const VerificationMeta(
    'linkedTxUuid',
  );
  @override
  late final GeneratedColumn<String> linkedTxUuid = GeneratedColumn<String>(
    'linked_tx_uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientUuid,
    userEmail,
    description,
    amount,
    dueDate,
    category,
    barcode,
    isRecurring,
    isCreditCardCharge,
    creditCardUuid,
    status,
    paidAt,
    linkedTransactionId,
    linkedTxUuid,
    isSynced,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_bills';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalBill> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_uuid')) {
      context.handle(
        _clientUuidMeta,
        clientUuid.isAcceptableOrUnknown(data['client_uuid']!, _clientUuidMeta),
      );
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
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    } else if (isInserting) {
      context.missing(_dueDateMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    }
    if (data.containsKey('is_recurring')) {
      context.handle(
        _isRecurringMeta,
        isRecurring.isAcceptableOrUnknown(
          data['is_recurring']!,
          _isRecurringMeta,
        ),
      );
    }
    if (data.containsKey('is_credit_card_charge')) {
      context.handle(
        _isCreditCardChargeMeta,
        isCreditCardCharge.isAcceptableOrUnknown(
          data['is_credit_card_charge']!,
          _isCreditCardChargeMeta,
        ),
      );
    }
    if (data.containsKey('credit_card_uuid')) {
      context.handle(
        _creditCardUuidMeta,
        creditCardUuid.isAcceptableOrUnknown(
          data['credit_card_uuid']!,
          _creditCardUuidMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('paid_at')) {
      context.handle(
        _paidAtMeta,
        paidAt.isAcceptableOrUnknown(data['paid_at']!, _paidAtMeta),
      );
    }
    if (data.containsKey('linked_transaction_id')) {
      context.handle(
        _linkedTransactionIdMeta,
        linkedTransactionId.isAcceptableOrUnknown(
          data['linked_transaction_id']!,
          _linkedTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('linked_tx_uuid')) {
      context.handle(
        _linkedTxUuidMeta,
        linkedTxUuid.isAcceptableOrUnknown(
          data['linked_tx_uuid']!,
          _linkedTxUuidMeta,
        ),
      );
    }
    if (data.containsKey('is_synced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalBill map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalBill(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_uuid'],
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
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      )!,
      isRecurring: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_recurring'],
      )!,
      isCreditCardCharge: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_credit_card_charge'],
      )!,
      creditCardUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credit_card_uuid'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      paidAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}paid_at'],
      ),
      linkedTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}linked_transaction_id'],
      ),
      linkedTxUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_tx_uuid'],
      ),
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $LocalBillsTable createAlias(String alias) {
    return $LocalBillsTable(attachedDatabase, alias);
  }
}

class LocalBill extends DataClass implements Insertable<LocalBill> {
  final int id;
  final String clientUuid;
  final String userEmail;
  final String description;
  final double amount;
  final DateTime dueDate;
  final String category;
  final String barcode;
  final bool isRecurring;
  final bool isCreditCardCharge;
  final String? creditCardUuid;
  final String status;
  final DateTime? paidAt;
  final int? linkedTransactionId;
  final String? linkedTxUuid;
  final bool isSynced;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  const LocalBill({
    required this.id,
    required this.clientUuid,
    required this.userEmail,
    required this.description,
    required this.amount,
    required this.dueDate,
    required this.category,
    required this.barcode,
    required this.isRecurring,
    required this.isCreditCardCharge,
    this.creditCardUuid,
    required this.status,
    this.paidAt,
    this.linkedTransactionId,
    this.linkedTxUuid,
    required this.isSynced,
    this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_uuid'] = Variable<String>(clientUuid);
    map['user_email'] = Variable<String>(userEmail);
    map['description'] = Variable<String>(description);
    map['amount'] = Variable<double>(amount);
    map['due_date'] = Variable<DateTime>(dueDate);
    map['category'] = Variable<String>(category);
    map['barcode'] = Variable<String>(barcode);
    map['is_recurring'] = Variable<bool>(isRecurring);
    map['is_credit_card_charge'] = Variable<bool>(isCreditCardCharge);
    if (!nullToAbsent || creditCardUuid != null) {
      map['credit_card_uuid'] = Variable<String>(creditCardUuid);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || paidAt != null) {
      map['paid_at'] = Variable<DateTime>(paidAt);
    }
    if (!nullToAbsent || linkedTransactionId != null) {
      map['linked_transaction_id'] = Variable<int>(linkedTransactionId);
    }
    if (!nullToAbsent || linkedTxUuid != null) {
      map['linked_tx_uuid'] = Variable<String>(linkedTxUuid);
    }
    map['is_synced'] = Variable<bool>(isSynced);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  LocalBillsCompanion toCompanion(bool nullToAbsent) {
    return LocalBillsCompanion(
      id: Value(id),
      clientUuid: Value(clientUuid),
      userEmail: Value(userEmail),
      description: Value(description),
      amount: Value(amount),
      dueDate: Value(dueDate),
      category: Value(category),
      barcode: Value(barcode),
      isRecurring: Value(isRecurring),
      isCreditCardCharge: Value(isCreditCardCharge),
      creditCardUuid: creditCardUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(creditCardUuid),
      status: Value(status),
      paidAt: paidAt == null && nullToAbsent
          ? const Value.absent()
          : Value(paidAt),
      linkedTransactionId: linkedTransactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedTransactionId),
      linkedTxUuid: linkedTxUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedTxUuid),
      isSynced: Value(isSynced),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory LocalBill.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalBill(
      id: serializer.fromJson<int>(json['id']),
      clientUuid: serializer.fromJson<String>(json['clientUuid']),
      userEmail: serializer.fromJson<String>(json['userEmail']),
      description: serializer.fromJson<String>(json['description']),
      amount: serializer.fromJson<double>(json['amount']),
      dueDate: serializer.fromJson<DateTime>(json['dueDate']),
      category: serializer.fromJson<String>(json['category']),
      barcode: serializer.fromJson<String>(json['barcode']),
      isRecurring: serializer.fromJson<bool>(json['isRecurring']),
      isCreditCardCharge: serializer.fromJson<bool>(json['isCreditCardCharge']),
      creditCardUuid: serializer.fromJson<String?>(json['creditCardUuid']),
      status: serializer.fromJson<String>(json['status']),
      paidAt: serializer.fromJson<DateTime?>(json['paidAt']),
      linkedTransactionId: serializer.fromJson<int?>(
        json['linkedTransactionId'],
      ),
      linkedTxUuid: serializer.fromJson<String?>(json['linkedTxUuid']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientUuid': serializer.toJson<String>(clientUuid),
      'userEmail': serializer.toJson<String>(userEmail),
      'description': serializer.toJson<String>(description),
      'amount': serializer.toJson<double>(amount),
      'dueDate': serializer.toJson<DateTime>(dueDate),
      'category': serializer.toJson<String>(category),
      'barcode': serializer.toJson<String>(barcode),
      'isRecurring': serializer.toJson<bool>(isRecurring),
      'isCreditCardCharge': serializer.toJson<bool>(isCreditCardCharge),
      'creditCardUuid': serializer.toJson<String?>(creditCardUuid),
      'status': serializer.toJson<String>(status),
      'paidAt': serializer.toJson<DateTime?>(paidAt),
      'linkedTransactionId': serializer.toJson<int?>(linkedTransactionId),
      'linkedTxUuid': serializer.toJson<String?>(linkedTxUuid),
      'isSynced': serializer.toJson<bool>(isSynced),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  LocalBill copyWith({
    int? id,
    String? clientUuid,
    String? userEmail,
    String? description,
    double? amount,
    DateTime? dueDate,
    String? category,
    String? barcode,
    bool? isRecurring,
    bool? isCreditCardCharge,
    Value<String?> creditCardUuid = const Value.absent(),
    String? status,
    Value<DateTime?> paidAt = const Value.absent(),
    Value<int?> linkedTransactionId = const Value.absent(),
    Value<String?> linkedTxUuid = const Value.absent(),
    bool? isSynced,
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => LocalBill(
    id: id ?? this.id,
    clientUuid: clientUuid ?? this.clientUuid,
    userEmail: userEmail ?? this.userEmail,
    description: description ?? this.description,
    amount: amount ?? this.amount,
    dueDate: dueDate ?? this.dueDate,
    category: category ?? this.category,
    barcode: barcode ?? this.barcode,
    isRecurring: isRecurring ?? this.isRecurring,
    isCreditCardCharge: isCreditCardCharge ?? this.isCreditCardCharge,
    creditCardUuid: creditCardUuid.present
        ? creditCardUuid.value
        : this.creditCardUuid,
    status: status ?? this.status,
    paidAt: paidAt.present ? paidAt.value : this.paidAt,
    linkedTransactionId: linkedTransactionId.present
        ? linkedTransactionId.value
        : this.linkedTransactionId,
    linkedTxUuid: linkedTxUuid.present ? linkedTxUuid.value : this.linkedTxUuid,
    isSynced: isSynced ?? this.isSynced,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  LocalBill copyWithCompanion(LocalBillsCompanion data) {
    return LocalBill(
      id: data.id.present ? data.id.value : this.id,
      clientUuid: data.clientUuid.present
          ? data.clientUuid.value
          : this.clientUuid,
      userEmail: data.userEmail.present ? data.userEmail.value : this.userEmail,
      description: data.description.present
          ? data.description.value
          : this.description,
      amount: data.amount.present ? data.amount.value : this.amount,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      category: data.category.present ? data.category.value : this.category,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      isRecurring: data.isRecurring.present
          ? data.isRecurring.value
          : this.isRecurring,
      isCreditCardCharge: data.isCreditCardCharge.present
          ? data.isCreditCardCharge.value
          : this.isCreditCardCharge,
      creditCardUuid: data.creditCardUuid.present
          ? data.creditCardUuid.value
          : this.creditCardUuid,
      status: data.status.present ? data.status.value : this.status,
      paidAt: data.paidAt.present ? data.paidAt.value : this.paidAt,
      linkedTransactionId: data.linkedTransactionId.present
          ? data.linkedTransactionId.value
          : this.linkedTransactionId,
      linkedTxUuid: data.linkedTxUuid.present
          ? data.linkedTxUuid.value
          : this.linkedTxUuid,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalBill(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('userEmail: $userEmail, ')
          ..write('description: $description, ')
          ..write('amount: $amount, ')
          ..write('dueDate: $dueDate, ')
          ..write('category: $category, ')
          ..write('barcode: $barcode, ')
          ..write('isRecurring: $isRecurring, ')
          ..write('isCreditCardCharge: $isCreditCardCharge, ')
          ..write('creditCardUuid: $creditCardUuid, ')
          ..write('status: $status, ')
          ..write('paidAt: $paidAt, ')
          ..write('linkedTransactionId: $linkedTransactionId, ')
          ..write('linkedTxUuid: $linkedTxUuid, ')
          ..write('isSynced: $isSynced, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientUuid,
    userEmail,
    description,
    amount,
    dueDate,
    category,
    barcode,
    isRecurring,
    isCreditCardCharge,
    creditCardUuid,
    status,
    paidAt,
    linkedTransactionId,
    linkedTxUuid,
    isSynced,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalBill &&
          other.id == this.id &&
          other.clientUuid == this.clientUuid &&
          other.userEmail == this.userEmail &&
          other.description == this.description &&
          other.amount == this.amount &&
          other.dueDate == this.dueDate &&
          other.category == this.category &&
          other.barcode == this.barcode &&
          other.isRecurring == this.isRecurring &&
          other.isCreditCardCharge == this.isCreditCardCharge &&
          other.creditCardUuid == this.creditCardUuid &&
          other.status == this.status &&
          other.paidAt == this.paidAt &&
          other.linkedTransactionId == this.linkedTransactionId &&
          other.linkedTxUuid == this.linkedTxUuid &&
          other.isSynced == this.isSynced &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class LocalBillsCompanion extends UpdateCompanion<LocalBill> {
  final Value<int> id;
  final Value<String> clientUuid;
  final Value<String> userEmail;
  final Value<String> description;
  final Value<double> amount;
  final Value<DateTime> dueDate;
  final Value<String> category;
  final Value<String> barcode;
  final Value<bool> isRecurring;
  final Value<bool> isCreditCardCharge;
  final Value<String?> creditCardUuid;
  final Value<String> status;
  final Value<DateTime?> paidAt;
  final Value<int?> linkedTransactionId;
  final Value<String?> linkedTxUuid;
  final Value<bool> isSynced;
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> deletedAt;
  const LocalBillsCompanion({
    this.id = const Value.absent(),
    this.clientUuid = const Value.absent(),
    this.userEmail = const Value.absent(),
    this.description = const Value.absent(),
    this.amount = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.category = const Value.absent(),
    this.barcode = const Value.absent(),
    this.isRecurring = const Value.absent(),
    this.isCreditCardCharge = const Value.absent(),
    this.creditCardUuid = const Value.absent(),
    this.status = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.linkedTransactionId = const Value.absent(),
    this.linkedTxUuid = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  LocalBillsCompanion.insert({
    this.id = const Value.absent(),
    this.clientUuid = const Value.absent(),
    this.userEmail = const Value.absent(),
    required String description,
    required double amount,
    required DateTime dueDate,
    required String category,
    this.barcode = const Value.absent(),
    this.isRecurring = const Value.absent(),
    this.isCreditCardCharge = const Value.absent(),
    this.creditCardUuid = const Value.absent(),
    this.status = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.linkedTransactionId = const Value.absent(),
    this.linkedTxUuid = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : description = Value(description),
       amount = Value(amount),
       dueDate = Value(dueDate),
       category = Value(category);
  static Insertable<LocalBill> custom({
    Expression<int>? id,
    Expression<String>? clientUuid,
    Expression<String>? userEmail,
    Expression<String>? description,
    Expression<double>? amount,
    Expression<DateTime>? dueDate,
    Expression<String>? category,
    Expression<String>? barcode,
    Expression<bool>? isRecurring,
    Expression<bool>? isCreditCardCharge,
    Expression<String>? creditCardUuid,
    Expression<String>? status,
    Expression<DateTime>? paidAt,
    Expression<int>? linkedTransactionId,
    Expression<String>? linkedTxUuid,
    Expression<bool>? isSynced,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientUuid != null) 'client_uuid': clientUuid,
      if (userEmail != null) 'user_email': userEmail,
      if (description != null) 'description': description,
      if (amount != null) 'amount': amount,
      if (dueDate != null) 'due_date': dueDate,
      if (category != null) 'category': category,
      if (barcode != null) 'barcode': barcode,
      if (isRecurring != null) 'is_recurring': isRecurring,
      if (isCreditCardCharge != null)
        'is_credit_card_charge': isCreditCardCharge,
      if (creditCardUuid != null) 'credit_card_uuid': creditCardUuid,
      if (status != null) 'status': status,
      if (paidAt != null) 'paid_at': paidAt,
      if (linkedTransactionId != null)
        'linked_transaction_id': linkedTransactionId,
      if (linkedTxUuid != null) 'linked_tx_uuid': linkedTxUuid,
      if (isSynced != null) 'is_synced': isSynced,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  LocalBillsCompanion copyWith({
    Value<int>? id,
    Value<String>? clientUuid,
    Value<String>? userEmail,
    Value<String>? description,
    Value<double>? amount,
    Value<DateTime>? dueDate,
    Value<String>? category,
    Value<String>? barcode,
    Value<bool>? isRecurring,
    Value<bool>? isCreditCardCharge,
    Value<String?>? creditCardUuid,
    Value<String>? status,
    Value<DateTime?>? paidAt,
    Value<int?>? linkedTransactionId,
    Value<String?>? linkedTxUuid,
    Value<bool>? isSynced,
    Value<DateTime?>? updatedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return LocalBillsCompanion(
      id: id ?? this.id,
      clientUuid: clientUuid ?? this.clientUuid,
      userEmail: userEmail ?? this.userEmail,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      category: category ?? this.category,
      barcode: barcode ?? this.barcode,
      isRecurring: isRecurring ?? this.isRecurring,
      isCreditCardCharge: isCreditCardCharge ?? this.isCreditCardCharge,
      creditCardUuid: creditCardUuid ?? this.creditCardUuid,
      status: status ?? this.status,
      paidAt: paidAt ?? this.paidAt,
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
      linkedTxUuid: linkedTxUuid ?? this.linkedTxUuid,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientUuid.present) {
      map['client_uuid'] = Variable<String>(clientUuid.value);
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
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (isRecurring.present) {
      map['is_recurring'] = Variable<bool>(isRecurring.value);
    }
    if (isCreditCardCharge.present) {
      map['is_credit_card_charge'] = Variable<bool>(isCreditCardCharge.value);
    }
    if (creditCardUuid.present) {
      map['credit_card_uuid'] = Variable<String>(creditCardUuid.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (paidAt.present) {
      map['paid_at'] = Variable<DateTime>(paidAt.value);
    }
    if (linkedTransactionId.present) {
      map['linked_transaction_id'] = Variable<int>(linkedTransactionId.value);
    }
    if (linkedTxUuid.present) {
      map['linked_tx_uuid'] = Variable<String>(linkedTxUuid.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalBillsCompanion(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('userEmail: $userEmail, ')
          ..write('description: $description, ')
          ..write('amount: $amount, ')
          ..write('dueDate: $dueDate, ')
          ..write('category: $category, ')
          ..write('barcode: $barcode, ')
          ..write('isRecurring: $isRecurring, ')
          ..write('isCreditCardCharge: $isCreditCardCharge, ')
          ..write('creditCardUuid: $creditCardUuid, ')
          ..write('status: $status, ')
          ..write('paidAt: $paidAt, ')
          ..write('linkedTransactionId: $linkedTransactionId, ')
          ..write('linkedTxUuid: $linkedTxUuid, ')
          ..write('isSynced: $isSynced, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $LocalCreditCardsTable extends LocalCreditCards
    with TableInfo<$LocalCreditCardsTable, LocalCreditCard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCreditCardsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _clientUuidMeta = const VerificationMeta(
    'clientUuid',
  );
  @override
  late final GeneratedColumn<String> clientUuid = GeneratedColumn<String>(
    'client_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
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
  static const VerificationMeta _targetMinPercentMeta = const VerificationMeta(
    'targetMinPercent',
  );
  @override
  late final GeneratedColumn<double> targetMinPercent = GeneratedColumn<double>(
    'target_min_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(50.0),
  );
  static const VerificationMeta _targetMaxPercentMeta = const VerificationMeta(
    'targetMaxPercent',
  );
  @override
  late final GeneratedColumn<double> targetMaxPercent = GeneratedColumn<double>(
    'target_max_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(80.0),
  );
  static const VerificationMeta _dueDayMeta = const VerificationMeta('dueDay');
  @override
  late final GeneratedColumn<int> dueDay = GeneratedColumn<int>(
    'due_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  static const VerificationMeta _isPrimaryMeta = const VerificationMeta(
    'isPrimary',
  );
  @override
  late final GeneratedColumn<bool> isPrimary = GeneratedColumn<bool>(
    'is_primary',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_primary" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientUuid,
    userEmail,
    name,
    limitAmount,
    targetMinPercent,
    targetMaxPercent,
    dueDay,
    isPrimary,
    isSynced,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_credit_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalCreditCard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_uuid')) {
      context.handle(
        _clientUuidMeta,
        clientUuid.isAcceptableOrUnknown(data['client_uuid']!, _clientUuidMeta),
      );
    }
    if (data.containsKey('user_email')) {
      context.handle(
        _userEmailMeta,
        userEmail.isAcceptableOrUnknown(data['user_email']!, _userEmailMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
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
    if (data.containsKey('target_min_percent')) {
      context.handle(
        _targetMinPercentMeta,
        targetMinPercent.isAcceptableOrUnknown(
          data['target_min_percent']!,
          _targetMinPercentMeta,
        ),
      );
    }
    if (data.containsKey('target_max_percent')) {
      context.handle(
        _targetMaxPercentMeta,
        targetMaxPercent.isAcceptableOrUnknown(
          data['target_max_percent']!,
          _targetMaxPercentMeta,
        ),
      );
    }
    if (data.containsKey('due_day')) {
      context.handle(
        _dueDayMeta,
        dueDay.isAcceptableOrUnknown(data['due_day']!, _dueDayMeta),
      );
    }
    if (data.containsKey('is_primary')) {
      context.handle(
        _isPrimaryMeta,
        isPrimary.isAcceptableOrUnknown(data['is_primary']!, _isPrimaryMeta),
      );
    }
    if (data.containsKey('is_synced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalCreditCard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCreditCard(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_uuid'],
      )!,
      userEmail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_email'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      limitAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}limit_amount'],
      )!,
      targetMinPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_min_percent'],
      )!,
      targetMaxPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_max_percent'],
      )!,
      dueDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_day'],
      )!,
      isPrimary: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_primary'],
      )!,
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $LocalCreditCardsTable createAlias(String alias) {
    return $LocalCreditCardsTable(attachedDatabase, alias);
  }
}

class LocalCreditCard extends DataClass implements Insertable<LocalCreditCard> {
  final int id;
  final String clientUuid;
  final String userEmail;
  final String name;
  final double limitAmount;
  final double targetMinPercent;
  final double targetMaxPercent;
  final int dueDay;
  final bool isPrimary;
  final bool isSynced;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  const LocalCreditCard({
    required this.id,
    required this.clientUuid,
    required this.userEmail,
    required this.name,
    required this.limitAmount,
    required this.targetMinPercent,
    required this.targetMaxPercent,
    required this.dueDay,
    required this.isPrimary,
    required this.isSynced,
    this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_uuid'] = Variable<String>(clientUuid);
    map['user_email'] = Variable<String>(userEmail);
    map['name'] = Variable<String>(name);
    map['limit_amount'] = Variable<double>(limitAmount);
    map['target_min_percent'] = Variable<double>(targetMinPercent);
    map['target_max_percent'] = Variable<double>(targetMaxPercent);
    map['due_day'] = Variable<int>(dueDay);
    map['is_primary'] = Variable<bool>(isPrimary);
    map['is_synced'] = Variable<bool>(isSynced);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  LocalCreditCardsCompanion toCompanion(bool nullToAbsent) {
    return LocalCreditCardsCompanion(
      id: Value(id),
      clientUuid: Value(clientUuid),
      userEmail: Value(userEmail),
      name: Value(name),
      limitAmount: Value(limitAmount),
      targetMinPercent: Value(targetMinPercent),
      targetMaxPercent: Value(targetMaxPercent),
      dueDay: Value(dueDay),
      isPrimary: Value(isPrimary),
      isSynced: Value(isSynced),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory LocalCreditCard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCreditCard(
      id: serializer.fromJson<int>(json['id']),
      clientUuid: serializer.fromJson<String>(json['clientUuid']),
      userEmail: serializer.fromJson<String>(json['userEmail']),
      name: serializer.fromJson<String>(json['name']),
      limitAmount: serializer.fromJson<double>(json['limitAmount']),
      targetMinPercent: serializer.fromJson<double>(json['targetMinPercent']),
      targetMaxPercent: serializer.fromJson<double>(json['targetMaxPercent']),
      dueDay: serializer.fromJson<int>(json['dueDay']),
      isPrimary: serializer.fromJson<bool>(json['isPrimary']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientUuid': serializer.toJson<String>(clientUuid),
      'userEmail': serializer.toJson<String>(userEmail),
      'name': serializer.toJson<String>(name),
      'limitAmount': serializer.toJson<double>(limitAmount),
      'targetMinPercent': serializer.toJson<double>(targetMinPercent),
      'targetMaxPercent': serializer.toJson<double>(targetMaxPercent),
      'dueDay': serializer.toJson<int>(dueDay),
      'isPrimary': serializer.toJson<bool>(isPrimary),
      'isSynced': serializer.toJson<bool>(isSynced),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  LocalCreditCard copyWith({
    int? id,
    String? clientUuid,
    String? userEmail,
    String? name,
    double? limitAmount,
    double? targetMinPercent,
    double? targetMaxPercent,
    int? dueDay,
    bool? isPrimary,
    bool? isSynced,
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => LocalCreditCard(
    id: id ?? this.id,
    clientUuid: clientUuid ?? this.clientUuid,
    userEmail: userEmail ?? this.userEmail,
    name: name ?? this.name,
    limitAmount: limitAmount ?? this.limitAmount,
    targetMinPercent: targetMinPercent ?? this.targetMinPercent,
    targetMaxPercent: targetMaxPercent ?? this.targetMaxPercent,
    dueDay: dueDay ?? this.dueDay,
    isPrimary: isPrimary ?? this.isPrimary,
    isSynced: isSynced ?? this.isSynced,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  LocalCreditCard copyWithCompanion(LocalCreditCardsCompanion data) {
    return LocalCreditCard(
      id: data.id.present ? data.id.value : this.id,
      clientUuid: data.clientUuid.present
          ? data.clientUuid.value
          : this.clientUuid,
      userEmail: data.userEmail.present ? data.userEmail.value : this.userEmail,
      name: data.name.present ? data.name.value : this.name,
      limitAmount: data.limitAmount.present
          ? data.limitAmount.value
          : this.limitAmount,
      targetMinPercent: data.targetMinPercent.present
          ? data.targetMinPercent.value
          : this.targetMinPercent,
      targetMaxPercent: data.targetMaxPercent.present
          ? data.targetMaxPercent.value
          : this.targetMaxPercent,
      dueDay: data.dueDay.present ? data.dueDay.value : this.dueDay,
      isPrimary: data.isPrimary.present ? data.isPrimary.value : this.isPrimary,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCreditCard(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('userEmail: $userEmail, ')
          ..write('name: $name, ')
          ..write('limitAmount: $limitAmount, ')
          ..write('targetMinPercent: $targetMinPercent, ')
          ..write('targetMaxPercent: $targetMaxPercent, ')
          ..write('dueDay: $dueDay, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('isSynced: $isSynced, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientUuid,
    userEmail,
    name,
    limitAmount,
    targetMinPercent,
    targetMaxPercent,
    dueDay,
    isPrimary,
    isSynced,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCreditCard &&
          other.id == this.id &&
          other.clientUuid == this.clientUuid &&
          other.userEmail == this.userEmail &&
          other.name == this.name &&
          other.limitAmount == this.limitAmount &&
          other.targetMinPercent == this.targetMinPercent &&
          other.targetMaxPercent == this.targetMaxPercent &&
          other.dueDay == this.dueDay &&
          other.isPrimary == this.isPrimary &&
          other.isSynced == this.isSynced &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class LocalCreditCardsCompanion extends UpdateCompanion<LocalCreditCard> {
  final Value<int> id;
  final Value<String> clientUuid;
  final Value<String> userEmail;
  final Value<String> name;
  final Value<double> limitAmount;
  final Value<double> targetMinPercent;
  final Value<double> targetMaxPercent;
  final Value<int> dueDay;
  final Value<bool> isPrimary;
  final Value<bool> isSynced;
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> deletedAt;
  const LocalCreditCardsCompanion({
    this.id = const Value.absent(),
    this.clientUuid = const Value.absent(),
    this.userEmail = const Value.absent(),
    this.name = const Value.absent(),
    this.limitAmount = const Value.absent(),
    this.targetMinPercent = const Value.absent(),
    this.targetMaxPercent = const Value.absent(),
    this.dueDay = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  LocalCreditCardsCompanion.insert({
    this.id = const Value.absent(),
    this.clientUuid = const Value.absent(),
    this.userEmail = const Value.absent(),
    required String name,
    required double limitAmount,
    this.targetMinPercent = const Value.absent(),
    this.targetMaxPercent = const Value.absent(),
    this.dueDay = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : name = Value(name),
       limitAmount = Value(limitAmount);
  static Insertable<LocalCreditCard> custom({
    Expression<int>? id,
    Expression<String>? clientUuid,
    Expression<String>? userEmail,
    Expression<String>? name,
    Expression<double>? limitAmount,
    Expression<double>? targetMinPercent,
    Expression<double>? targetMaxPercent,
    Expression<int>? dueDay,
    Expression<bool>? isPrimary,
    Expression<bool>? isSynced,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientUuid != null) 'client_uuid': clientUuid,
      if (userEmail != null) 'user_email': userEmail,
      if (name != null) 'name': name,
      if (limitAmount != null) 'limit_amount': limitAmount,
      if (targetMinPercent != null) 'target_min_percent': targetMinPercent,
      if (targetMaxPercent != null) 'target_max_percent': targetMaxPercent,
      if (dueDay != null) 'due_day': dueDay,
      if (isPrimary != null) 'is_primary': isPrimary,
      if (isSynced != null) 'is_synced': isSynced,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  LocalCreditCardsCompanion copyWith({
    Value<int>? id,
    Value<String>? clientUuid,
    Value<String>? userEmail,
    Value<String>? name,
    Value<double>? limitAmount,
    Value<double>? targetMinPercent,
    Value<double>? targetMaxPercent,
    Value<int>? dueDay,
    Value<bool>? isPrimary,
    Value<bool>? isSynced,
    Value<DateTime?>? updatedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return LocalCreditCardsCompanion(
      id: id ?? this.id,
      clientUuid: clientUuid ?? this.clientUuid,
      userEmail: userEmail ?? this.userEmail,
      name: name ?? this.name,
      limitAmount: limitAmount ?? this.limitAmount,
      targetMinPercent: targetMinPercent ?? this.targetMinPercent,
      targetMaxPercent: targetMaxPercent ?? this.targetMaxPercent,
      dueDay: dueDay ?? this.dueDay,
      isPrimary: isPrimary ?? this.isPrimary,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientUuid.present) {
      map['client_uuid'] = Variable<String>(clientUuid.value);
    }
    if (userEmail.present) {
      map['user_email'] = Variable<String>(userEmail.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (limitAmount.present) {
      map['limit_amount'] = Variable<double>(limitAmount.value);
    }
    if (targetMinPercent.present) {
      map['target_min_percent'] = Variable<double>(targetMinPercent.value);
    }
    if (targetMaxPercent.present) {
      map['target_max_percent'] = Variable<double>(targetMaxPercent.value);
    }
    if (dueDay.present) {
      map['due_day'] = Variable<int>(dueDay.value);
    }
    if (isPrimary.present) {
      map['is_primary'] = Variable<bool>(isPrimary.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCreditCardsCompanion(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('userEmail: $userEmail, ')
          ..write('name: $name, ')
          ..write('limitAmount: $limitAmount, ')
          ..write('targetMinPercent: $targetMinPercent, ')
          ..write('targetMaxPercent: $targetMaxPercent, ')
          ..write('dueDay: $dueDay, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('isSynced: $isSynced, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
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
    userEmail,
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
    if (data.containsKey('user_email')) {
      context.handle(
        _userEmailMeta,
        userEmail.isAcceptableOrUnknown(data['user_email']!, _userEmailMeta),
      );
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
      userEmail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_email'],
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
  final String userEmail;
  final String category;
  final double limitAmount;
  final int month;
  final int year;
  const LocalBudget({
    required this.id,
    required this.userEmail,
    required this.category,
    required this.limitAmount,
    required this.month,
    required this.year,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_email'] = Variable<String>(userEmail);
    map['category'] = Variable<String>(category);
    map['limit_amount'] = Variable<double>(limitAmount);
    map['month'] = Variable<int>(month);
    map['year'] = Variable<int>(year);
    return map;
  }

  LocalBudgetsCompanion toCompanion(bool nullToAbsent) {
    return LocalBudgetsCompanion(
      id: Value(id),
      userEmail: Value(userEmail),
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
      userEmail: serializer.fromJson<String>(json['userEmail']),
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
      'userEmail': serializer.toJson<String>(userEmail),
      'category': serializer.toJson<String>(category),
      'limitAmount': serializer.toJson<double>(limitAmount),
      'month': serializer.toJson<int>(month),
      'year': serializer.toJson<int>(year),
    };
  }

  LocalBudget copyWith({
    int? id,
    String? userEmail,
    String? category,
    double? limitAmount,
    int? month,
    int? year,
  }) => LocalBudget(
    id: id ?? this.id,
    userEmail: userEmail ?? this.userEmail,
    category: category ?? this.category,
    limitAmount: limitAmount ?? this.limitAmount,
    month: month ?? this.month,
    year: year ?? this.year,
  );
  LocalBudget copyWithCompanion(LocalBudgetsCompanion data) {
    return LocalBudget(
      id: data.id.present ? data.id.value : this.id,
      userEmail: data.userEmail.present ? data.userEmail.value : this.userEmail,
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
          ..write('userEmail: $userEmail, ')
          ..write('category: $category, ')
          ..write('limitAmount: $limitAmount, ')
          ..write('month: $month, ')
          ..write('year: $year')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, userEmail, category, limitAmount, month, year);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalBudget &&
          other.id == this.id &&
          other.userEmail == this.userEmail &&
          other.category == this.category &&
          other.limitAmount == this.limitAmount &&
          other.month == this.month &&
          other.year == this.year);
}

class LocalBudgetsCompanion extends UpdateCompanion<LocalBudget> {
  final Value<int> id;
  final Value<String> userEmail;
  final Value<String> category;
  final Value<double> limitAmount;
  final Value<int> month;
  final Value<int> year;
  const LocalBudgetsCompanion({
    this.id = const Value.absent(),
    this.userEmail = const Value.absent(),
    this.category = const Value.absent(),
    this.limitAmount = const Value.absent(),
    this.month = const Value.absent(),
    this.year = const Value.absent(),
  });
  LocalBudgetsCompanion.insert({
    this.id = const Value.absent(),
    this.userEmail = const Value.absent(),
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
    Expression<String>? userEmail,
    Expression<String>? category,
    Expression<double>? limitAmount,
    Expression<int>? month,
    Expression<int>? year,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userEmail != null) 'user_email': userEmail,
      if (category != null) 'category': category,
      if (limitAmount != null) 'limit_amount': limitAmount,
      if (month != null) 'month': month,
      if (year != null) 'year': year,
    });
  }

  LocalBudgetsCompanion copyWith({
    Value<int>? id,
    Value<String>? userEmail,
    Value<String>? category,
    Value<double>? limitAmount,
    Value<int>? month,
    Value<int>? year,
  }) {
    return LocalBudgetsCompanion(
      id: id ?? this.id,
      userEmail: userEmail ?? this.userEmail,
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
    if (userEmail.present) {
      map['user_email'] = Variable<String>(userEmail.value);
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
          ..write('userEmail: $userEmail, ')
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
    userEmail,
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
    if (data.containsKey('user_email')) {
      context.handle(
        _userEmailMeta,
        userEmail.isAcceptableOrUnknown(data['user_email']!, _userEmailMeta),
      );
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
      userEmail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_email'],
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
  final String userEmail;
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
    required this.userEmail,
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
    map['user_email'] = Variable<String>(userEmail);
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
      userEmail: Value(userEmail),
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
      userEmail: serializer.fromJson<String>(json['userEmail']),
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
      'userEmail': serializer.toJson<String>(userEmail),
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
    String? userEmail,
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
    userEmail: userEmail ?? this.userEmail,
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
      userEmail: data.userEmail.present ? data.userEmail.value : this.userEmail,
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
          ..write('userEmail: $userEmail, ')
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
    userEmail,
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
          other.userEmail == this.userEmail &&
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
  final Value<String> userEmail;
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
    this.userEmail = const Value.absent(),
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
    this.userEmail = const Value.absent(),
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
    Expression<String>? userEmail,
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
      if (userEmail != null) 'user_email': userEmail,
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
    Value<String>? userEmail,
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
      userEmail: userEmail ?? this.userEmail,
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
    if (userEmail.present) {
      map['user_email'] = Variable<String>(userEmail.value);
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
          ..write('userEmail: $userEmail, ')
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
    userEmail,
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
    if (data.containsKey('user_email')) {
      context.handle(
        _userEmailMeta,
        userEmail.isAcceptableOrUnknown(data['user_email']!, _userEmailMeta),
      );
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
      userEmail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_email'],
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
  final String userEmail;
  final int? transactionId;
  final String rawSuggestion;
  final double confidenceScore;
  final String categorySuggested;
  final String budgetTip;
  final DateTime createdAt;
  const LocalAgentInsight({
    required this.id,
    required this.userEmail,
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
    map['user_email'] = Variable<String>(userEmail);
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
      userEmail: Value(userEmail),
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
      userEmail: serializer.fromJson<String>(json['userEmail']),
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
      'userEmail': serializer.toJson<String>(userEmail),
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
    String? userEmail,
    Value<int?> transactionId = const Value.absent(),
    String? rawSuggestion,
    double? confidenceScore,
    String? categorySuggested,
    String? budgetTip,
    DateTime? createdAt,
  }) => LocalAgentInsight(
    id: id ?? this.id,
    userEmail: userEmail ?? this.userEmail,
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
      userEmail: data.userEmail.present ? data.userEmail.value : this.userEmail,
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
          ..write('userEmail: $userEmail, ')
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
    userEmail,
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
          other.userEmail == this.userEmail &&
          other.transactionId == this.transactionId &&
          other.rawSuggestion == this.rawSuggestion &&
          other.confidenceScore == this.confidenceScore &&
          other.categorySuggested == this.categorySuggested &&
          other.budgetTip == this.budgetTip &&
          other.createdAt == this.createdAt);
}

class LocalAgentInsightsCompanion extends UpdateCompanion<LocalAgentInsight> {
  final Value<int> id;
  final Value<String> userEmail;
  final Value<int?> transactionId;
  final Value<String> rawSuggestion;
  final Value<double> confidenceScore;
  final Value<String> categorySuggested;
  final Value<String> budgetTip;
  final Value<DateTime> createdAt;
  const LocalAgentInsightsCompanion({
    this.id = const Value.absent(),
    this.userEmail = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.rawSuggestion = const Value.absent(),
    this.confidenceScore = const Value.absent(),
    this.categorySuggested = const Value.absent(),
    this.budgetTip = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LocalAgentInsightsCompanion.insert({
    this.id = const Value.absent(),
    this.userEmail = const Value.absent(),
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
    Expression<String>? userEmail,
    Expression<int>? transactionId,
    Expression<String>? rawSuggestion,
    Expression<double>? confidenceScore,
    Expression<String>? categorySuggested,
    Expression<String>? budgetTip,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userEmail != null) 'user_email': userEmail,
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
    Value<String>? userEmail,
    Value<int?>? transactionId,
    Value<String>? rawSuggestion,
    Value<double>? confidenceScore,
    Value<String>? categorySuggested,
    Value<String>? budgetTip,
    Value<DateTime>? createdAt,
  }) {
    return LocalAgentInsightsCompanion(
      id: id ?? this.id,
      userEmail: userEmail ?? this.userEmail,
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
    if (userEmail.present) {
      map['user_email'] = Variable<String>(userEmail.value);
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
          ..write('userEmail: $userEmail, ')
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
  late final $LocalBillsTable localBills = $LocalBillsTable(this);
  late final $LocalCreditCardsTable localCreditCards = $LocalCreditCardsTable(
    this,
  );
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
    localBills,
    localCreditCards,
    localBudgets,
    localMetrics,
    localAgentInsights,
  ];
}

typedef $$LocalTransactionsTableCreateCompanionBuilder =
    LocalTransactionsCompanion Function({
      Value<int> id,
      Value<String> clientUuid,
      Value<String> userEmail,
      required String description,
      required double amount,
      required DateTime date,
      required String type,
      required String category,
      Value<String> paymentMethod,
      Value<String?> creditCardUuid,
      Value<bool> isSynced,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$LocalTransactionsTableUpdateCompanionBuilder =
    LocalTransactionsCompanion Function({
      Value<int> id,
      Value<String> clientUuid,
      Value<String> userEmail,
      Value<String> description,
      Value<double> amount,
      Value<DateTime> date,
      Value<String> type,
      Value<String> category,
      Value<String> paymentMethod,
      Value<String?> creditCardUuid,
      Value<bool> isSynced,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
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

  ColumnFilters<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
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

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creditCardUuid => $composableBuilder(
    column: $table.creditCardUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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

  ColumnOrderings<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
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

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creditCardUuid => $composableBuilder(
    column: $table.creditCardUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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

  GeneratedColumn<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => column,
  );

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

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get creditCardUuid => $composableBuilder(
    column: $table.creditCardUuid,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
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
                Value<String> clientUuid = const Value.absent(),
                Value<String> userEmail = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
                Value<String?> creditCardUuid = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => LocalTransactionsCompanion(
                id: id,
                clientUuid: clientUuid,
                userEmail: userEmail,
                description: description,
                amount: amount,
                date: date,
                type: type,
                category: category,
                paymentMethod: paymentMethod,
                creditCardUuid: creditCardUuid,
                isSynced: isSynced,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientUuid = const Value.absent(),
                Value<String> userEmail = const Value.absent(),
                required String description,
                required double amount,
                required DateTime date,
                required String type,
                required String category,
                Value<String> paymentMethod = const Value.absent(),
                Value<String?> creditCardUuid = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => LocalTransactionsCompanion.insert(
                id: id,
                clientUuid: clientUuid,
                userEmail: userEmail,
                description: description,
                amount: amount,
                date: date,
                type: type,
                category: category,
                paymentMethod: paymentMethod,
                creditCardUuid: creditCardUuid,
                isSynced: isSynced,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
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
typedef $$LocalBillsTableCreateCompanionBuilder = LocalBillsCompanion Function({
  Value<int> id,
  Value<String> clientUuid,
  Value<String> userEmail,
  required String description,
  required double amount,
  required DateTime dueDate,
  required String category,
  Value<String> barcode,
  Value<bool> isRecurring,
  Value<bool> isCreditCardCharge,
  Value<String?> creditCardUuid,
  Value<String> status,
  Value<DateTime?> paidAt,
  Value<int?> linkedTransactionId,
  Value<String?> linkedTxUuid,
  Value<bool> isSynced,
  Value<DateTime?> updatedAt,
  Value<DateTime?> deletedAt,
});
typedef $$LocalBillsTableUpdateCompanionBuilder = LocalBillsCompanion Function({
  Value<int> id,
  Value<String> clientUuid,
  Value<String> userEmail,
  Value<String> description,
  Value<double> amount,
  Value<DateTime> dueDate,
  Value<String> category,
  Value<String> barcode,
  Value<bool> isRecurring,
  Value<bool> isCreditCardCharge,
  Value<String?> creditCardUuid,
  Value<String> status,
  Value<DateTime?> paidAt,
  Value<int?> linkedTransactionId,
  Value<String?> linkedTxUuid,
  Value<bool> isSynced,
  Value<DateTime?> updatedAt,
  Value<DateTime?> deletedAt,
});

class $$LocalBillsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalBillsTable> {
  $$LocalBillsTableFilterComposer({
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

  ColumnFilters<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
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

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRecurring => $composableBuilder(
    column: $table.isRecurring,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCreditCardCharge => $composableBuilder(
    column: $table.isCreditCardCharge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creditCardUuid => $composableBuilder(
    column: $table.creditCardUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get linkedTransactionId => $composableBuilder(
    column: $table.linkedTransactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedTxUuid => $composableBuilder(
    column: $table.linkedTxUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalBillsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalBillsTable> {
  $$LocalBillsTableOrderingComposer({
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

  ColumnOrderings<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
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

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRecurring => $composableBuilder(
    column: $table.isRecurring,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCreditCardCharge => $composableBuilder(
    column: $table.isCreditCardCharge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creditCardUuid => $composableBuilder(
    column: $table.creditCardUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get linkedTransactionId => $composableBuilder(
    column: $table.linkedTransactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedTxUuid => $composableBuilder(
    column: $table.linkedTxUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalBillsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalBillsTable> {
  $$LocalBillsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userEmail =>
      $composableBuilder(column: $table.userEmail, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<bool> get isRecurring => $composableBuilder(
    column: $table.isRecurring,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCreditCardCharge => $composableBuilder(
    column: $table.isCreditCardCharge,
    builder: (column) => column,
  );

  GeneratedColumn<String> get creditCardUuid => $composableBuilder(
    column: $table.creditCardUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get paidAt =>
      $composableBuilder(column: $table.paidAt, builder: (column) => column);

  GeneratedColumn<int> get linkedTransactionId => $composableBuilder(
    column: $table.linkedTransactionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkedTxUuid => $composableBuilder(
    column: $table.linkedTxUuid,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$LocalBillsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalBillsTable,
          LocalBill,
          $$LocalBillsTableFilterComposer,
          $$LocalBillsTableOrderingComposer,
          $$LocalBillsTableAnnotationComposer,
          $$LocalBillsTableCreateCompanionBuilder,
          $$LocalBillsTableUpdateCompanionBuilder,
          (
            LocalBill,
            BaseReferences<_$AppDatabase, $LocalBillsTable, LocalBill>,
          ),
          LocalBill,
          PrefetchHooks Function()
        > {
  $$LocalBillsTableTableManager(_$AppDatabase db, $LocalBillsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalBillsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalBillsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalBillsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientUuid = const Value.absent(),
                Value<String> userEmail = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<DateTime> dueDate = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> barcode = const Value.absent(),
                Value<bool> isRecurring = const Value.absent(),
                Value<bool> isCreditCardCharge = const Value.absent(),
                Value<String?> creditCardUuid = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> paidAt = const Value.absent(),
                Value<int?> linkedTransactionId = const Value.absent(),
                Value<String?> linkedTxUuid = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => LocalBillsCompanion(
                id: id,
                clientUuid: clientUuid,
                userEmail: userEmail,
                description: description,
                amount: amount,
                dueDate: dueDate,
                category: category,
                barcode: barcode,
                isRecurring: isRecurring,
                isCreditCardCharge: isCreditCardCharge,
                creditCardUuid: creditCardUuid,
                status: status,
                paidAt: paidAt,
                linkedTransactionId: linkedTransactionId,
                linkedTxUuid: linkedTxUuid,
                isSynced: isSynced,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientUuid = const Value.absent(),
                Value<String> userEmail = const Value.absent(),
                required String description,
                required double amount,
                required DateTime dueDate,
                required String category,
                Value<String> barcode = const Value.absent(),
                Value<bool> isRecurring = const Value.absent(),
                Value<bool> isCreditCardCharge = const Value.absent(),
                Value<String?> creditCardUuid = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> paidAt = const Value.absent(),
                Value<int?> linkedTransactionId = const Value.absent(),
                Value<String?> linkedTxUuid = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => LocalBillsCompanion.insert(
                id: id,
                clientUuid: clientUuid,
                userEmail: userEmail,
                description: description,
                amount: amount,
                dueDate: dueDate,
                category: category,
                barcode: barcode,
                isRecurring: isRecurring,
                isCreditCardCharge: isCreditCardCharge,
                creditCardUuid: creditCardUuid,
                status: status,
                paidAt: paidAt,
                linkedTransactionId: linkedTransactionId,
                linkedTxUuid: linkedTxUuid,
                isSynced: isSynced,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalBillsTable, LocalBill>(table),
                  BaseReferences<_$AppDatabase, $LocalBillsTable, LocalBill>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalBillsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalBillsTable,
      LocalBill,
      $$LocalBillsTableFilterComposer,
      $$LocalBillsTableOrderingComposer,
      $$LocalBillsTableAnnotationComposer,
      $$LocalBillsTableCreateCompanionBuilder,
      $$LocalBillsTableUpdateCompanionBuilder,
      (LocalBill, BaseReferences<_$AppDatabase, $LocalBillsTable, LocalBill>),
      LocalBill,
      PrefetchHooks Function()
    >;
typedef $$LocalCreditCardsTableCreateCompanionBuilder =
    LocalCreditCardsCompanion Function({
      Value<int> id,
      Value<String> clientUuid,
      Value<String> userEmail,
      required String name,
      required double limitAmount,
      Value<double> targetMinPercent,
      Value<double> targetMaxPercent,
      Value<int> dueDay,
      Value<bool> isPrimary,
      Value<bool> isSynced,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$LocalCreditCardsTableUpdateCompanionBuilder =
    LocalCreditCardsCompanion Function({
      Value<int> id,
      Value<String> clientUuid,
      Value<String> userEmail,
      Value<String> name,
      Value<double> limitAmount,
      Value<double> targetMinPercent,
      Value<double> targetMaxPercent,
      Value<int> dueDay,
      Value<bool> isPrimary,
      Value<bool> isSynced,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
    });

class $$LocalCreditCardsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalCreditCardsTable> {
  $$LocalCreditCardsTableFilterComposer({
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

  ColumnFilters<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userEmail => $composableBuilder(
    column: $table.userEmail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get limitAmount => $composableBuilder(
    column: $table.limitAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetMinPercent => $composableBuilder(
    column: $table.targetMinPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetMaxPercent => $composableBuilder(
    column: $table.targetMaxPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueDay => $composableBuilder(
    column: $table.dueDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalCreditCardsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalCreditCardsTable> {
  $$LocalCreditCardsTableOrderingComposer({
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

  ColumnOrderings<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userEmail => $composableBuilder(
    column: $table.userEmail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get limitAmount => $composableBuilder(
    column: $table.limitAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetMinPercent => $composableBuilder(
    column: $table.targetMinPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetMaxPercent => $composableBuilder(
    column: $table.targetMaxPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueDay => $composableBuilder(
    column: $table.dueDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalCreditCardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalCreditCardsTable> {
  $$LocalCreditCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userEmail =>
      $composableBuilder(column: $table.userEmail, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get limitAmount => $composableBuilder(
    column: $table.limitAmount,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetMinPercent => $composableBuilder(
    column: $table.targetMinPercent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetMaxPercent => $composableBuilder(
    column: $table.targetMaxPercent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dueDay =>
      $composableBuilder(column: $table.dueDay, builder: (column) => column);

  GeneratedColumn<bool> get isPrimary =>
      $composableBuilder(column: $table.isPrimary, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$LocalCreditCardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalCreditCardsTable,
          LocalCreditCard,
          $$LocalCreditCardsTableFilterComposer,
          $$LocalCreditCardsTableOrderingComposer,
          $$LocalCreditCardsTableAnnotationComposer,
          $$LocalCreditCardsTableCreateCompanionBuilder,
          $$LocalCreditCardsTableUpdateCompanionBuilder,
          (
            LocalCreditCard,
            BaseReferences<
              _$AppDatabase,
              $LocalCreditCardsTable,
              LocalCreditCard
            >,
          ),
          LocalCreditCard,
          PrefetchHooks Function()
        > {
  $$LocalCreditCardsTableTableManager(
    _$AppDatabase db,
    $LocalCreditCardsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCreditCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCreditCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalCreditCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientUuid = const Value.absent(),
                Value<String> userEmail = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> limitAmount = const Value.absent(),
                Value<double> targetMinPercent = const Value.absent(),
                Value<double> targetMaxPercent = const Value.absent(),
                Value<int> dueDay = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => LocalCreditCardsCompanion(
                id: id,
                clientUuid: clientUuid,
                userEmail: userEmail,
                name: name,
                limitAmount: limitAmount,
                targetMinPercent: targetMinPercent,
                targetMaxPercent: targetMaxPercent,
                dueDay: dueDay,
                isPrimary: isPrimary,
                isSynced: isSynced,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientUuid = const Value.absent(),
                Value<String> userEmail = const Value.absent(),
                required String name,
                required double limitAmount,
                Value<double> targetMinPercent = const Value.absent(),
                Value<double> targetMaxPercent = const Value.absent(),
                Value<int> dueDay = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => LocalCreditCardsCompanion.insert(
                id: id,
                clientUuid: clientUuid,
                userEmail: userEmail,
                name: name,
                limitAmount: limitAmount,
                targetMinPercent: targetMinPercent,
                targetMaxPercent: targetMaxPercent,
                dueDay: dueDay,
                isPrimary: isPrimary,
                isSynced: isSynced,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalCreditCardsTable, LocalCreditCard>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalCreditCardsTable,
                    LocalCreditCard
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalCreditCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalCreditCardsTable,
      LocalCreditCard,
      $$LocalCreditCardsTableFilterComposer,
      $$LocalCreditCardsTableOrderingComposer,
      $$LocalCreditCardsTableAnnotationComposer,
      $$LocalCreditCardsTableCreateCompanionBuilder,
      $$LocalCreditCardsTableUpdateCompanionBuilder,
      (
        LocalCreditCard,
        BaseReferences<_$AppDatabase, $LocalCreditCardsTable, LocalCreditCard>,
      ),
      LocalCreditCard,
      PrefetchHooks Function()
    >;
typedef $$LocalBudgetsTableCreateCompanionBuilder =
    LocalBudgetsCompanion Function({
      Value<int> id,
      Value<String> userEmail,
      required String category,
      required double limitAmount,
      required int month,
      required int year,
    });
typedef $$LocalBudgetsTableUpdateCompanionBuilder =
    LocalBudgetsCompanion Function({
      Value<int> id,
      Value<String> userEmail,
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

  ColumnFilters<String> get userEmail => $composableBuilder(
    column: $table.userEmail,
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

  ColumnOrderings<String> get userEmail => $composableBuilder(
    column: $table.userEmail,
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

  GeneratedColumn<String> get userEmail =>
      $composableBuilder(column: $table.userEmail, builder: (column) => column);

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
                Value<String> userEmail = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<double> limitAmount = const Value.absent(),
                Value<int> month = const Value.absent(),
                Value<int> year = const Value.absent(),
              }) => LocalBudgetsCompanion(
                id: id,
                userEmail: userEmail,
                category: category,
                limitAmount: limitAmount,
                month: month,
                year: year,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> userEmail = const Value.absent(),
                required String category,
                required double limitAmount,
                required int month,
                required int year,
              }) => LocalBudgetsCompanion.insert(
                id: id,
                userEmail: userEmail,
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
      Value<String> userEmail,
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
      Value<String> userEmail,
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

  ColumnFilters<String> get userEmail => $composableBuilder(
    column: $table.userEmail,
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

  ColumnOrderings<String> get userEmail => $composableBuilder(
    column: $table.userEmail,
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

  GeneratedColumn<String> get userEmail =>
      $composableBuilder(column: $table.userEmail, builder: (column) => column);

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
                Value<String> userEmail = const Value.absent(),
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
                userEmail: userEmail,
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
                Value<String> userEmail = const Value.absent(),
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
                userEmail: userEmail,
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
      Value<String> userEmail,
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
      Value<String> userEmail,
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

  ColumnFilters<String> get userEmail => $composableBuilder(
    column: $table.userEmail,
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

  ColumnOrderings<String> get userEmail => $composableBuilder(
    column: $table.userEmail,
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

  GeneratedColumn<String> get userEmail =>
      $composableBuilder(column: $table.userEmail, builder: (column) => column);

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
                Value<String> userEmail = const Value.absent(),
                Value<int?> transactionId = const Value.absent(),
                Value<String> rawSuggestion = const Value.absent(),
                Value<double> confidenceScore = const Value.absent(),
                Value<String> categorySuggested = const Value.absent(),
                Value<String> budgetTip = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LocalAgentInsightsCompanion(
                id: id,
                userEmail: userEmail,
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
                Value<String> userEmail = const Value.absent(),
                Value<int?> transactionId = const Value.absent(),
                required String rawSuggestion,
                required double confidenceScore,
                required String categorySuggested,
                required String budgetTip,
                required DateTime createdAt,
              }) => LocalAgentInsightsCompanion.insert(
                id: id,
                userEmail: userEmail,
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
  $$LocalBillsTableTableManager get localBills =>
      $$LocalBillsTableTableManager(_db, _db.localBills);
  $$LocalCreditCardsTableTableManager get localCreditCards =>
      $$LocalCreditCardsTableTableManager(_db, _db.localCreditCards);
  $$LocalBudgetsTableTableManager get localBudgets =>
      $$LocalBudgetsTableTableManager(_db, _db.localBudgets);
  $$LocalMetricsTableTableManager get localMetrics =>
      $$LocalMetricsTableTableManager(_db, _db.localMetrics);
  $$LocalAgentInsightsTableTableManager get localAgentInsights =>
      $$LocalAgentInsightsTableTableManager(_db, _db.localAgentInsights);
}
