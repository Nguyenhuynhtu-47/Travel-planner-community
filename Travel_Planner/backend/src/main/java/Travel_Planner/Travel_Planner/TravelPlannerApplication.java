package Travel_Planner.Travel_Planner;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@EnableScheduling
@SpringBootApplication
public class TravelPlannerApplication {

	public static void main(String[] args) {
		SpringApplication.run(TravelPlannerApplication.class, args);
	}

}
