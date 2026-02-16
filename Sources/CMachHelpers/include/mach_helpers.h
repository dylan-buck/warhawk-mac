#ifndef MACH_HELPERS_H
#define MACH_HELPERS_H

#include <sys/types.h>
#include <mach/mach.h>
#include <mach/mach_vm.h>

// Attach to a process by PID, returning a task port
kern_return_t mach_attach(pid_t pid, mach_port_t *task);

// Read memory from a task
kern_return_t mach_read_memory(mach_port_t task, mach_vm_address_t address,
                               mach_vm_size_t size, void *buffer);

// Write memory to a task
kern_return_t mach_write_memory(mach_port_t task, mach_vm_address_t address,
                                mach_vm_size_t size, const void *buffer);

// Iterate memory regions to find a large mapping
// Returns the base address of the first region >= min_size bytes
// starting at or after hint_address
kern_return_t mach_find_large_region(mach_port_t task,
                                     mach_vm_address_t hint_address,
                                     mach_vm_size_t min_size,
                                     mach_vm_address_t *out_address,
                                     mach_vm_size_t *out_size);

#endif // MACH_HELPERS_H
