class BankDetails {
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final String bankBranchName;
  final String bankbookImg;
  final String status;

  BankDetails({
    required this.accountNumber,
    required this.ifscCode,
    required this.bankName,
    required this.bankBranchName,
    required this.bankbookImg,
    required this.status,
  });

  factory BankDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return BankDetails(
        accountNumber: '',
        ifscCode: '',
        bankName: '',
        bankBranchName: '',
        bankbookImg: '',
        status: '',
      );
    }
    return BankDetails(
      accountNumber: json['account_number']?.toString().trim() ?? '',
      ifscCode: json['ifsc_code']?.toString().trim() ?? '',
      bankName: json['bank_name']?.toString().trim() ?? '',
      bankBranchName: json['bank_branch_name']?.toString().trim() ?? '',
      bankbookImg: json['bankbook_img']?.toString().trim() ?? '',
      status: json['status']?.toString().trim() ?? '',
    );
  }
}

class PersonalDetails {
  final String dob;
  final String dobFormatted;
  final String education;
  final String employeePhoto;
  final String houseNo;
  final String street;
  final String city;
  final String district;
  final String pincode;

  PersonalDetails({
    required this.dob,
    required this.dobFormatted,
    required this.education,
    required this.employeePhoto,
    required this.houseNo,
    required this.street,
    required this.city,
    required this.district,
    required this.pincode,
  });

  factory PersonalDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return PersonalDetails(
        dob: '',
        dobFormatted: '',
        education: '',
        employeePhoto: '',
        houseNo: '',
        street: '',
        city: '',
        district: '',
        pincode: '',
      );
    }
    return PersonalDetails(
      dob: json['dob']?.toString().trim() ?? '',
      dobFormatted: json['dob_formatted']?.toString().trim() ?? '',
      education: json['education']?.toString().trim() ?? '',
      employeePhoto: json['employee_photo']?.toString().trim() ?? '',
      houseNo: json['house_no']?.toString().trim() ?? '',
      street: json['street']?.toString().trim() ?? '',
      city: json['city']?.toString().trim() ?? '',
      district: json['district']?.toString().trim() ?? '',
      pincode: json['pincode']?.toString().trim() ?? '',
    );
  }

  String get fullAddress {
    final parts = [houseNo, street, city, district, pincode]
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.isNotEmpty ? parts.join(', ') : 'Not Specified';
  }
}

class ContactDetails {
  final String relativeType;
  final String contactPersonName;
  final String contactPersonPhoneNumber;
  final String contactHouseNo;
  final String contactStreet;
  final String contactCity;
  final String contactDistrict;
  final String contactPincode;

  ContactDetails({
    required this.relativeType,
    required this.contactPersonName,
    required this.contactPersonPhoneNumber,
    required this.contactHouseNo,
    required this.contactStreet,
    required this.contactCity,
    required this.contactDistrict,
    required this.contactPincode,
  });

  factory ContactDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ContactDetails(
        relativeType: '',
        contactPersonName: '',
        contactPersonPhoneNumber: '',
        contactHouseNo: '',
        contactStreet: '',
        contactCity: '',
        contactDistrict: '',
        contactPincode: '',
      );
    }
    return ContactDetails(
      relativeType: json['relative_type']?.toString().trim() ?? '',
      contactPersonName: json['contact_person_name']?.toString().trim() ?? '',
      contactPersonPhoneNumber: json['contact_person_phone_number']?.toString().trim() ?? '',
      contactHouseNo: json['contact_house_no']?.toString().trim() ?? '',
      contactStreet: json['contact_street']?.toString().trim() ?? '',
      contactCity: json['contact_city']?.toString().trim() ?? '',
      contactDistrict: json['contact_district']?.toString().trim() ?? '',
      contactPincode: json['contact_pincode']?.toString().trim() ?? '',
    );
  }

  String get fullContactAddress {
    final parts = [contactHouseNo, contactStreet, contactCity, contactDistrict, contactPincode]
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.isNotEmpty ? parts.join(', ') : 'Not Specified';
  }
}

class UserProfileData {
  final String employeeId;
  final String employeeCode;
  final String loginCode;
  final String permission;
  final String companyName;
  final String payslipLocation;
  final String zone;
  final String branch;
  final String branchName;
  final String employeeName;
  final String email;
  final String mobileNumber;
  final String designation;
  final String doj;
  final String dojFormatted;
  final String payslipStatus;
  final String basicPay;
  final String allowanceAmount;
  final String mobileRecharge;
  final String esiStatus;
  final String esiNumber;
  final String pfStatus;
  final String pfNumber;
  final String pfAmount;
  final String panNumber;
  final String aadharNumber;
  final String aadharcardImg;
  final String pancardImg;
  final String licenceImg;
  final String licenceNumber;
  final String electricalLicence;
  final String electricalLicenceImg;

  final BankDetails bankDetails;
  final PersonalDetails personalDetails;
  final ContactDetails contactDetails;

  UserProfileData({
    required this.employeeId,
    required this.employeeCode,
    required this.loginCode,
    required this.permission,
    required this.companyName,
    required this.payslipLocation,
    required this.zone,
    required this.branch,
    required this.branchName,
    required this.employeeName,
    required this.email,
    required this.mobileNumber,
    required this.designation,
    required this.doj,
    required this.dojFormatted,
    required this.payslipStatus,
    required this.basicPay,
    required this.allowanceAmount,
    required this.mobileRecharge,
    required this.esiStatus,
    required this.esiNumber,
    required this.pfStatus,
    required this.pfNumber,
    required this.pfAmount,
    required this.panNumber,
    required this.aadharNumber,
    required this.aadharcardImg,
    required this.pancardImg,
    required this.licenceImg,
    required this.licenceNumber,
    required this.electricalLicence,
    required this.electricalLicenceImg,
    required this.bankDetails,
    required this.personalDetails,
    required this.contactDetails,
  });

  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    return UserProfileData(
      employeeId: json['employee_id']?.toString().trim() ?? '',
      employeeCode: json['employee_code']?.toString().trim() ?? '',
      loginCode: json['login_code']?.toString().trim() ?? '',
      permission: json['permission']?.toString().trim() ?? '',
      companyName: json['company_name']?.toString().trim() ?? '',
      payslipLocation: json['payslip_location']?.toString().trim() ?? '',
      zone: json['zone']?.toString().trim() ?? '',
      branch: json['branch']?.toString().trim() ?? '',
      branchName: json['branch_name']?.toString().trim() ?? '',
      employeeName: json['employee_name']?.toString().trim() ?? '',
      email: json['email']?.toString().trim() ?? '',
      mobileNumber: json['mobile_number']?.toString().trim() ?? '',
      designation: json['designation']?.toString().trim() ?? '',
      doj: json['doj']?.toString().trim() ?? '',
      dojFormatted: json['doj_formatted']?.toString().trim() ?? '',
      payslipStatus: json['payslip_status']?.toString().trim() ?? '',
      basicPay: json['basic_pay']?.toString().trim() ?? '0',
      allowanceAmount: json['allowance_amount']?.toString().trim() ?? '0',
      mobileRecharge: json['mobile_recharge']?.toString().trim() ?? '0',
      esiStatus: json['esi_status']?.toString().trim() ?? '',
      esiNumber: json['esi_number']?.toString().trim() ?? '',
      pfStatus: json['pf_status']?.toString().trim() ?? '',
      pfNumber: json['pf_number']?.toString().trim() ?? '',
      pfAmount: json['pf_amount']?.toString().trim() ?? '0',
      panNumber: json['pan_number']?.toString().trim() ?? '',
      aadharNumber: json['aadhar_number']?.toString().trim() ?? '',
      aadharcardImg: json['aadharcard_img']?.toString().trim() ?? '',
      pancardImg: json['pancard_img']?.toString().trim() ?? '',
      licenceImg: json['licence_img']?.toString().trim() ?? '',
      licenceNumber: json['licence_number']?.toString().trim() ?? '',
      electricalLicence: json['electrical_licence']?.toString().trim() ?? '',
      electricalLicenceImg: json['electrical_licence_img']?.toString().trim() ?? '',
      bankDetails: BankDetails.fromJson(json['bank_details'] as Map<String, dynamic>?),
      personalDetails: PersonalDetails.fromJson(json['personal_details'] as Map<String, dynamic>?),
      contactDetails: ContactDetails.fromJson(json['contact_details'] as Map<String, dynamic>?),
    );
  }
}
