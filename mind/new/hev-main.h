/*
 ============================================================================
 Name        : hev-main.h
 Author      : hev <r@hev.cc>
 Copyright   : Copyright (c) 2019 - 2023 hev
 Description : Main
 ============================================================================
 */

#ifndef __BLUELINK_PROXY_SERVICE_MODULE_H__
#define __BLUELINK_PROXY_SERVICE_MODULE_H__

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <sys/types.h>
#define CTLIOCGINFO 0xc0644e03UL

struct UtunCtlRec {
    u_int32_t   ctl_id;
    char        unit_name[96];
};

struct SockAddrSys {
    u_char      sa_len;
    u_char      sa_family;
    u_int16_t   reserved;
    u_int32_t   ctl_id;
    u_int32_t   unit;
    u_int32_t   pad[5];
};

/**
 * BluelinkProxyServiceStart:
 * @config_file: settings file path
 * @interface_fd: network device file descriptor
 *
 * Initialize and launch the bluelink proxy service, this function will block until
 * BluelinkProxyServiceStop is called or an error occurs.
 *
 * Returns: returns zero on successful, otherwise returns -1.
 *
 * Since: 2.4.6
 */
int BluelinkProxyServiceStart(const char *config_file, int interface_fd);

/**
 * BluelinkProxyServiceStartFromFile:
 * @config_file: settings file path
 * @interface_fd: network device file descriptor
 *
 * Initialize and launch the bluelink proxy service from a file, this function will block until
 * BluelinkProxyServiceStop is called or an error occurs.
 *
 * Returns: returns zero on successful, otherwise returns -1.
 *
 * Since: 2.6.7
 */
int BluelinkProxyServiceStartFromFile(const char *config_file, int interface_fd);

/**
 * BluelinkProxyServiceStartFromMemory:
 * @config_memory: settings data in memory
 * @memory_size: the byte length of settings data
 * @interface_fd: network device file descriptor
 *
 * Initialize and launch the bluelink proxy service from memory data, this function will block until
 * BluelinkProxyServiceStop is called or an error occurs.
 *
 * Returns: returns zero on successful, otherwise returns -1.
 *
 * Since: 2.6.7
 */
int BluelinkProxyServiceStartFromMemory(const unsigned char *config_memory,
                                          unsigned int memory_size, int interface_fd);

/**
 * BluelinkProxyServiceStop:
 *
 * Gracefully terminate the bluelink proxy service.
 *
 * Since: 2.4.6
 */
void BluelinkProxyServiceStop(void);

/**
 * BluelinkProxyServiceGetMetrics:
 * @egress_packets (out): outbound packets count
 * @egress_bytes (out): outbound bytes count
 * @ingress_packets (out): inbound packets count
 * @ingress_bytes (out): inbound bytes count
 *
 * Retrieve performance metrics of bluelink proxy service.
 *
 * Since: 2.6.5
 */
void BluelinkProxyServiceGetMetrics(size_t *egress_packets, size_t *egress_bytes,
                                           size_t *ingress_packets, size_t *ingress_bytes);

#ifdef __cplusplus
}
#endif

#endif /* __BLUELINK_PROXY_SERVICE_MODULE_H__ */
