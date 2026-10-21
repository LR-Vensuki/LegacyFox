/* LegacyFox SDK overlay: os_log came with iOS 10. Logging goes nowhere on
 * iOS 4-7 (Gecko's own logging still reaches stderr). */
#ifndef LEGACYFOX_OS_LOG_H
#define LEGACYFOX_OS_LOG_H
#pragma GCC system_header
typedef void *os_log_t;
typedef unsigned char os_log_type_t;
#define OS_LOG_TYPE_DEFAULT 0x00
#define OS_LOG_TYPE_INFO 0x01
#define OS_LOG_TYPE_DEBUG 0x02
#define OS_LOG_TYPE_ERROR 0x10
#define OS_LOG_TYPE_FAULT 0x11
#define OS_LOG_DEFAULT ((os_log_t)0)
#define os_log_create(subsystem, category) ((os_log_t)0)
#define os_log_type_enabled(log, type) 0
#define os_log_with_type(log, type, ...) ((void)0)
#define os_log(log, ...) ((void)0)
#define os_log_info(log, ...) ((void)0)
#define os_log_debug(log, ...) ((void)0)
#define os_log_error(log, ...) ((void)0)
#define os_log_fault(log, ...) ((void)0)
#endif
