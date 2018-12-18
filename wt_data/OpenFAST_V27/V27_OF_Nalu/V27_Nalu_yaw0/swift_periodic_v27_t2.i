Simulations:
  - name: sim1
    time_integrator: ti_1
    optimizer: opt1


# Specify the linear system solvers.
linear_solvers:

  # solver for scalar equations
  - name: solve_scalar
    type: tpetra
    method: gmres
    preconditioner: sgs
    tolerance: 1e-6
    max_iterations: 75
    kspace: 75
    output_level: 0

  # solver for the pressure Poisson equation
  - name: solve_cont
    type: tpetra
    method: gmres
    preconditioner: muelu
    tolerance: 1e-6
    max_iterations: 75
    kspace: 75
    output_level: 0
    recompute_preconditioner: no
    muelu_xml_file_name: ./milestone.xml


# Specify the differnt physics realms.  Here, we have one for the fluid and one for io transfer to south/west inflow planes.
realms:

  # The fluid realm that uses the 3 km x 3 km x 1 km atmospheric LES mesh.
  - name: fluidRealm
    mesh: mesh/coarse_abl_mesh_pp.g  #for test, same as pre
    #mesh: rst/precursor.rst
    use_edges: yes
    automatic_decomposition_type: rcb

    # This defines the equations to be solved: momentum, pressure, static enthalpy, 
    # and subgrid-scale turbulent kinetic energy.  The equation system will be iterated
    # a maximum of 2 outer iterations.
    equation_systems:
      name: theEqSys
      max_iterations: 4

      # This defines which solver to use for each equation set.  See the
      # "linear_solvers" block.  All use the scalar solver, except pressure.
      solver_system_specification:
        velocity: solve_scalar
        pressure: solve_cont
        enthalpy: solve_scalar
        turbulent_ke: solve_scalar

      # This defines the equation systems, maximum number of inner iterations,
      # and scaled nonlinear residual tolerance.
      systems:

        - LowMachEOM:
            name: myLowMach
            max_iterations: 1
            convergence_tolerance: 1.0e-5

        - Enthalpy:
            name: myEnth
            max_iterations: 1
            convergence_tolerance: 1.0e-5

        - TurbKineticEnergy:
            name: myTke
            max_iterations: 1
            convergence_tolerance: 1.0e-5

    # Specify the properties of the fluid, in this case air.
    material_properties:

      target_name: [fluid_part]
      #target_name: [fluid_part, fluid_part.pyramid_5._urpconv, fluid_part.tetrahedron_4._urpconv, fluid_part.pyramid_5._urpconv.tetrahedron_4._urpconv]

      constant_specification:
       universal_gas_constant: 8314.4621
       reference_pressure: 101325.0

      reference_quantities:
        - species_name: Air
          mw: 29.0
          mass_fraction: 1.0

      specifications:
 
        # Density here was computed such that P_ref = rho_ref*(R/mw)*300K
        - name: density
          type: constant
          value: 1.178037722969475

        - name: viscosity
          type: constant
          value: 1.2E-5

        - name: specific_heat
          type: constant
          value: 1000.0

    # The initial conditions are that pressure is uniformly 0 Pa 
    #and previously the velocity was 
    #  8 m/s from 245 degrees (southwest).  [5.9400150116484323, -6.7613772015315998, 0.0]
    #Initial temperature is not
    # specified here because later it is specified as read in from file.
    # Also, perturbations are applied near the surface to initiate turbulence.
    initial_conditions:
      - constant: ic_1
        target_name: [fluid_part]
        #target_name: [fluid_part, fluid_part.pyramid_5._urpconv, fluid_part.tetrahedron_4._urpconv, fluid_part.pyramid_5._urpconv.tetrahedron_4._urpconv]
        value:
          pressure: 0.0
          velocity: [8.0, 0.0, 0.0]

    # Boundary conditions are periodic on the north, south, east, and west
    # sides.  The lower boundary condition is a wall that uses an atmospheric
    # rough wall shear stress model.  The upper boundary is a stress free
    # rigid lid applied through symmetry, but the temperature is set to hold
    # a specified boundary normal gradient that matches the stable layer
    # immediately below.
    boundary_conditions:

    - periodic_boundary_condition: bc_north_south
      target_name: [north, south]
      #target_name: [Ymin, Ymax] # [north, south]
      periodic_user_data:
        search_tolerance: 0.0001

    - periodic_boundary_condition: bc_east_west
      target_name: [east, west]
      periodic_user_data:
        search_tolerance: 0.0001
 
    #- inflow_boundary_condition: bc_west
    #  target_name: west
    #  inflow_user_data:
    #    velocity: [8.0, 0, 0]
    #    temperature: 300
    #    external_data: yes

    #- open_boundary_condition: bc_east
    #  target_name: east
    #  open_user_data:
    #    velocity: [0.0, 0.0, 0.0]
    #    temperature: 300.0
    #    pressure: 0.0
      
        
    - symmetry_boundary_condition: bc_upper
      target_name: upper
      #target_name: Zmax  #top
      symmetry_user_data:
        normal_temperature_gradient: -0.003

    - wall_boundary_condition: bc_lower
      target_name: lower
      #target_name: Zmin  #terrain
      wall_user_data:
        velocity: [0,0,0]
        use_abl_wall_function: yes
        heat_flux: 0.0
        reference_temperature: 300.0
        roughness_height: 0.1
        gravity_vector_component: 3

    solution_options:
      name: myOptions
      turbulence_model: ksgs
      interp_rhou_together_for_mdot: yes
      activate_open_mdot_correction: no
      

      # Pressure is not fixed anywhere on the boundaries, so set it at
      # the node closest to the specified location.
      fix_pressure_at_node:
        value: 0.0
        node_lookup_type: spatial_location
        location: [100.0, 2500.0, 1.0]
        search_target_part: [fluid_part]
        #search_target_part: [fluid_part, fluid_part.pyramid_5._urpconv, fluid_part.tetrahedron_4._urpconv, fluid_part.pyramid_5._urpconv.tetrahedron_4._urpconv]
        search_method: stk_kdtree

      options:

        # Model constants for the 1-eq k SGS model.
        - turbulence_model_constants:
            kappa: 0.4
            cEps: 0.93
            cmuEps: 0.0673

        - laminar_prandtl:
            enthalpy: 0.7

        # Turbulent Prandtl number is 1/3 following Moeng (1984).
        - turbulent_prandtl:
            enthalpy: 0.3333

        # SGS viscosity is divided by Schmidt number in the k SGS diffusion
        # term.  In Moeng (1984), SGS viscosity is multiplied by 2, hence
        # we divide by 1/2
        - turbulent_schmidt:
            turbulent_ke: 0.5

        # The momentum source terms are a Boussinesq bouyancy term,
        # Coriolis from Earth''s rotation, and a source term to drive
        # the planar-averaged wind at a certain height to a certain
        # speed.
        - source_terms:
            momentum: 
              - buoyancy_boussinesq
              - EarthCoriolis
              - actuator
            turbulent_ke:
              - rodi
        - source_term_parameters:
            momentum: [0.003, 0.000646, 0.0]   #average from abl_Uy_sources.dat files

        - user_constants:
            reference_density: 1.178037722969475
            reference_temperature: 300.0
            gravity: [0.0,0.0,-9.81]
            thermal_expansion_coefficient: 3.33333333e-3           
            east_vector: [1.0, 0.0, 0.0]
            north_vector: [0.0, 1.0, 0.0]
            latitude: 33.6
            earth_angular_velocity: 7.2921159e-5

        - limiter:
            pressure: no
            velocity: no
            enthalpy: yes 

        - peclet_function_form:
            velocity: classic
            enthalpy: tanh
            turbulent_ke: tanh

        - peclet_function_tanh_transition:
            velocity: 50000.0
            enthalpy: 2.0
            turbulent_ke: 2.0

        - peclet_function_tanh_width:
            velocity: 200.0
            enthalpy: 1.0
            turbulent_ke: 1.0

        # This means that the initial temperature is read in
        # from the Exodus mesh/field file.
        - input_variables_from_file:
            temperature: temperature

    # This defines the ABL forcing to drive the winds to 8 m/s from
    # 245 degrees (southwest) at 90 m above the surface in a planar 
    # averaged sense.  
#    abl_forcing:
#      search_method: stk_kdtree
#      search_tolerance: 0.0001
#      search_expansion_factor: 1.5
#
#      from_target_part: [fluid_part, fluid_part.pyramid_5._urpconv, fluid_part.tetrahedron_4._urpconv, fluid_part.pyramid_5._urpconv.tetrahedron_4._urpconv]
#
#      momentum:
#        type: computed
#        relaxation_factor: 1.0
#        heights: [90.0]
#        target_part_format: "zplane_%06.1f"
#        velocity_x:
#          - [0.0, 6.5]
#          - [900000.0, 6.5]
#
#        velocity_y:
#          - [0.0, 0]
#          - [90000.0, 0]
#
#        velocity_z:
#          - [0.0, 0.0]
#          - [90000.0, 0.0]
#

#
    actuator:
      type: ActLineFAST
      search_method: boost_rtree
      search_target_part: [fluid_part]
      #search_target_part: [fluid_part, fluid_part.pyramid_5._urpconv, fluid_part.tetrahedron_4._urpconv, fluid_part.pyramid_5._urpconv.tetrahedron_4._urpconv]
      n_turbines_glob: 2
      dry_run:  False
      debug:    False
      t_start: 0.0
      simStart: init # init/trueRestart/restartDriverInitFAST
      t_max:    1200.0
      dt_fast: 0.005
      n_every_checkpoint: 100
#      
      Turbine0:
        procNo: 0
        num_force_pts_blade: 50
        num_force_pts_tower: 20
        epsilon: [ 1.1, 1.1, 1.1 ]
        turbine_base_pos: [1000.00, 1500.00, 0.0 ]
        turbine_hub_pos: [998.208, 1500.00, 32.1 ]
        restart_filename: ""
        fast_input_filename: "V27_Nalu/Turbine1.fst"
        turb_id:  1
        turbine_name: V27_1
        
      Turbine1:
        procNo: 0
        num_force_pts_blade: 50
        num_force_pts_tower: 20
        epsilon: [ 1.1, 1.1, 1.1 ]
        turbine_base_pos: [1134.97, 1500.17, 0.0 ]
        turbine_hub_pos: [1133.179, 1500.17, 32.1 ]
        restart_filename: ""
        fast_input_filename: "V27_Nalu/Turbine2.fst"
        turb_id:  2
        turbine_name: V27_2

    output:
      output_data_base_name: out/turbine_1.e
      output_frequency: 10
      output_nodse_set: no
      output_variables:
       - velocity
       - pressure
       - enthalpy
       - temperature
       - turbulent_ke

    restart:
      restart_data_base_name: rst/turb_1.rst
      output_frequency: 10
      restart_start: 0
#      restart_time: 60000

#  - name: ioRealm
#    mesh: ./out/abl_io_results.e
#    type: external_field_provider
#
#    field_registration:
#      specifications:
#
#        - field_name: velocity_bc
#          target_name: [west]
#          field_size: 3
#          field_type: node_rank
#
#        - field_name: cont_velocity_bc
#          target_name: [west]
#          field_size: 3
#          field_type: node_rank
#
#        - field_name: temperature_bc
#          target_name: [west]
#          field_size: 1
#          field_type: node_rank
#
#        - field_name: ksgs_bc
#          target_name: [west]
#          field_size: 1
#          field_type: node_rank

#    solution_options:
#      name: myOptions
#      input_variables_interpolate_in_time: yes
#      input_variables_from_file_restoration_time: 0.0

#      options:
#        - input_variables_from_file:
#            velocity_bc: velocity_bc
#            cont_velocity_bc: cont_velocity_bc
#            temperature_bc: temperature_bc
#            ksgs_bc: ksgs_bc
#transfers:
#
#  - name: west
#    type: geometric
#    realm_pair: [ioRealm, fluidRealm]
#    #mesh_part_pair: [block_101, west]
#    mesh_part_pair: [west, west]
#    objective: external_data
#    search_tolerance: 5.0e-4
#    transfer_variables:
#      - [velocity_bc, velocity]
#      - [velocity_bc, velocity_bc]
#      - [temperature_bc, temperature]
#      - [temperature_bc, temperature_bc]
#      - [ksgs_bc, turbulent_ke]
#      - [ksgs_bc, tke_bc]



# This defines the time step size, count, etc.
Time_Integrators:
  - StandardTimeIntegrator:
      name: ti_1
      start_time: 0.0
      termination_step_count: 300
      time_step: 0.02
      time_stepping_type: fixed
      time_step_count: 0
      second_order_accuracy: yes

      realms:
        - fluidRealm
        #- ioRealm
