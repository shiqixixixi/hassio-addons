package storage

const (
	// TotalCountKey is key name for total count of storage
	TotalCountKey = "gorush-total-count"

	// IosSuccessKey is key name or ios success count of storage
	IosSuccessKey = "gorush-ios-success-count"

	// IosErrorKey is key name or ios success error of storage
	IosErrorKey = "gorush-ios-error-count"

	// AndroidSuccessKey is key name for android success count of storage
	AndroidSuccessKey = "gorush-android-success-count"

	// AndroidErrorKey is key name for android error count of storage
	AndroidErrorKey = "gorush-android-error-count"

	// HuaweiSuccessKey is key name for huawei success count of storage
	HuaweiSuccessKey = "gorush-huawei-success-count"

	// HuaweiErrorKey is key name for huawei error count of storage
	HuaweiErrorKey = "gorush-huawei-error-count"

	// MISuccessKey is key name for mi success count of storage
	MISuccessKey = "gorush-mi-success-count"

	// MIErrorKey is key name for mi error count of storage
	MIErrorKey = "gorush-mi-error-count"
)

// Storage interface
type Storage interface {
	Init() error
	Reset()
	AddTotalCount(int64)
	AddIosSuccess(int64)
	AddIosError(int64)
	AddAndroidSuccess(int64)
	AddAndroidError(int64)
	AddHuaweiSuccess(int64)
	AddHuaweiError(int64)
	AddMISuccess(int64)
	AddMIError(int64)
	GetTotalCount() int64
	GetIosSuccess() int64
	GetIosError() int64
	GetAndroidSuccess() int64
	GetAndroidError() int64
	GetHuaweiSuccess() int64
	GetHuaweiError() int64
	Close() error
}
