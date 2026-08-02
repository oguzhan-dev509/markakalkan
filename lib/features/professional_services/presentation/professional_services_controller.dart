import 'package:flutter/foundation.dart';

import '../data/professional_services_callable_client.dart';
import '../domain/professional_service_models.dart';

enum ProfessionalServicesControllerStatus { idle, running, succeeded, failed }

class ProfessionalServicesController extends ChangeNotifier {
  ProfessionalServicesController({required ProfessionalServicesGateway gateway})
    : _gateway = gateway;

  final ProfessionalServicesGateway _gateway;

  ProfessionalServicesControllerStatus _status =
      ProfessionalServicesControllerStatus.idle;
  ProfessionalServiceOperation? _selectedOperation;
  ProfessionalServiceResult? _result;
  ProfessionalServicesClientFailure? _failure;

  ProfessionalServicesControllerStatus get status => _status;
  ProfessionalServiceOperation? get selectedOperation => _selectedOperation;
  ProfessionalServiceResult? get result => _result;
  ProfessionalServicesClientFailure? get failure => _failure;
  bool get isRunning => _status == ProfessionalServicesControllerStatus.running;

  void selectOperation(ProfessionalServiceOperation operation) {
    if (_selectedOperation == operation) return;
    _selectedOperation = operation;
    _result = null;
    _failure = null;
    _status = ProfessionalServicesControllerStatus.idle;
    notifyListeners();
  }

  Future<void> execute(ProfessionalServiceCommand command) async {
    if (isRunning) return;

    _selectedOperation = command.operation;
    _status = ProfessionalServicesControllerStatus.running;
    _result = null;
    _failure = null;
    notifyListeners();

    try {
      _result = await _gateway.execute(command);
      _status = ProfessionalServicesControllerStatus.succeeded;
    } on ProfessionalServicesClientFailure catch (error) {
      _failure = error;
      _status = ProfessionalServicesControllerStatus.failed;
    } catch (_) {
      _failure = const ProfessionalServicesClientFailure(
        code: 'controller-internal',
        message: 'Profesyonel Hizmetler işlemi tamamlanamadı.',
      );
      _status = ProfessionalServicesControllerStatus.failed;
    }
    notifyListeners();
  }

  void reset() {
    _status = ProfessionalServicesControllerStatus.idle;
    _selectedOperation = null;
    _result = null;
    _failure = null;
    notifyListeners();
  }
}
