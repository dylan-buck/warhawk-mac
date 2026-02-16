#include "mach_helpers.h"
#include <sys/types.h>
#include <mach/mach_vm.h>
#include <string.h>

kern_return_t mach_attach(pid_t pid, mach_port_t *task) {
    return task_for_pid(mach_task_self(), pid, task);
}

kern_return_t mach_read_memory(mach_port_t task, mach_vm_address_t address,
                               mach_vm_size_t size, void *buffer) {
    mach_vm_size_t out_size = size;
    return mach_vm_read_overwrite(task, address, size,
                                  (mach_vm_address_t)buffer, &out_size);
}

kern_return_t mach_write_memory(mach_port_t task, mach_vm_address_t address,
                                mach_vm_size_t size, const void *buffer) {
    return mach_vm_write(task, address, (vm_offset_t)buffer,
                         (mach_msg_type_number_t)size);
}

kern_return_t mach_find_large_region(mach_port_t task,
                                     mach_vm_address_t hint_address,
                                     mach_vm_size_t min_size,
                                     mach_vm_address_t *out_address,
                                     mach_vm_size_t *out_size) {
    mach_vm_address_t address = hint_address;
    mach_vm_size_t region_size;
    natural_t depth = 1;
    vm_region_submap_info_data_64_t info;
    mach_msg_type_number_t count;

    while (1) {
        region_size = 0;
        count = VM_REGION_SUBMAP_INFO_COUNT_64;
        kern_return_t kr = mach_vm_region_recurse(task, &address, &region_size,
                                                   &depth, (vm_region_recurse_info_t)&info, &count);
        if (kr != KERN_SUCCESS) {
            return kr;
        }

        if (region_size >= min_size) {
            *out_address = address;
            *out_size = region_size;
            return KERN_SUCCESS;
        }

        address += region_size;
    }

    return KERN_FAILURE;
}
