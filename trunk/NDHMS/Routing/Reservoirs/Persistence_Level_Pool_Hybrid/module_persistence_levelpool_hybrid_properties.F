! This module defines and instantiates objects
! for a hybrid type reservoir's
! parameters/properties. Properties holds
! static/unchanging variables that are
! set when the given reservoir object is
! initialized/instantiated.

module module_persistence_levelpool_hybrid_properties
    use module_reservoir_utilities, only: read_netcdf_lake_id, &
                                          read_persistence_netcdf_gage_id, &
                                          read_persistence_netcdf_real_2D_parameters, &
                                          handle_err
    use module_reservoir, only: reservoir_properties
    use netcdf
    implicit none

    ! Extend/derive hybrid properties from the abstract base
    ! type for reservoir properties.
    type, extends(reservoir_properties) :: hybrid_properties_interface
        real    :: min_storage                  ! minimum storage (cubic meters)
        real    :: max_storage                  ! maximum storage (cubic meters)
        real    :: lake_area                    ! area of reservoir (km^2)
        real    :: orifice_elevation            ! orifice elevation (meters AMSL)
        integer :: lake_number                  ! lake number
        integer :: gage_id
        integer :: observation_lookback_hours
        integer :: observation_update_time_interval_seconds
        integer :: weight_update_time_interval
        real, allocatable, dimension(:) :: persistence_weighted_coefficients

    contains

        procedure :: init => hybrid_properties_init
        procedure :: destroy => hybrid_properties_destroy

    end type hybrid_properties_interface

    integer, parameter :: seconds_in_day = 86400

contains

    ! Hybrid Properties Constructor
    subroutine hybrid_properties_init(this, lake_area, lake_max_water_elevation, orifice_elevation, lake_number, &
        observation_lookback_hours, observation_update_time_interval_seconds, persistence_parameter_file)
        implicit none
        class(hybrid_properties_interface), intent(inout) :: this ! the type object being initialized
        real,    intent(in)          :: lake_area                    ! area of lake (km^2)
        real,    intent(in)          :: lake_max_water_elevation     ! max water elevation (meters)
        real,    intent(in)          :: orifice_elevation            ! orifice elevation (meters AMSL)
        integer, intent(in)          :: lake_number                  ! lake number
        integer, intent(in)          :: observation_lookback_hours
        integer, intent(in)          :: observation_update_time_interval_seconds
        character(len=*), intent(in) :: persistence_parameter_file
        integer                      :: ncid, var_id, lake_id_index
        integer                      :: status                        ! status of reading NetCDF
        integer                      :: number_of_weights, number_of_lakes
        real, allocatable, dimension(:,:) :: temp_real_2D_array

        this%lake_area = lake_area * 1.0E6

        this%orifice_elevation = orifice_elevation

        this%lake_number = lake_number

        this%observation_lookback_hours = observation_lookback_hours

        this%observation_update_time_interval_seconds = observation_update_time_interval_seconds

        this%weight_update_time_interval = seconds_in_day

        this%min_storage = 0.0

        this%max_storage = (lake_max_water_elevation - orifice_elevation) * lake_area * 1.0E6

        ! Open Persistence Reservoir Parameter NetCDF file
        status = nf90_open(path = persistence_parameter_file, mode = nf90_nowrite, ncid = ncid)
        if (status /= nf90_noerr) call handle_err(status, "Could not open persistence reservoir parameter file")

        ! Read relevant properties from Persistence Parameter NetCDF
        call read_netcdf_lake_id(ncid, lake_number, "usgs_lake_id", lake_id_index)

        call read_persistence_netcdf_gage_id(ncid, lake_id_index, "usgs_gage_id", this%gage_id)

        call read_persistence_netcdf_real_2D_parameters(ncid, lake_id_index, "usgs_persistence_coefficients", var_id, number_of_weights, number_of_lakes)

        allocate(this%persistence_weighted_coefficients(number_of_weights))

        allocate(temp_real_2D_array(number_of_weights, number_of_lakes))

        status = nf90_get_var(ncid, var_id, temp_real_2D_array)
        if (status /= nf90_noerr) call handle_err(status, "usgs_persistence_coefficients")

        this%persistence_weighted_coefficients(:) = temp_real_2D_array(:, lake_id_index)

        if(allocated(temp_real_2D_array)) deallocate(temp_real_2D_array)

        status = nf90_close(ncid)
        if (status /= nf90_noerr) call handle_err(status, "Could not close persistence reservoir parameter file")

    end subroutine hybrid_properties_init

    ! Hybrid Properties Destructor
    subroutine hybrid_properties_destroy(this)
        implicit none
        class(hybrid_properties_interface), intent(inout) :: this ! the type object being destroyed
    end subroutine hybrid_properties_destroy

end module module_persistence_levelpool_hybrid_properties
