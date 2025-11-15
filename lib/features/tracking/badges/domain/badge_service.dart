import '../badge_repository.dart';

class BadgeService {
  final BadgeRepository badgeRepo;
  //BADGE LOGIC FOR STEPS

  BadgeService({required this.badgeRepo});

  Future<void> checkStepBadges(int stepsToday) async{
    //STEP STARTER (1,000 steps)
    if (stepsToday >= 1000){
      await badgeRepo.awardBadge(
        badgeName: "Step Starter",
        description: "Walked 1,000 steps in one day!",
        iconUrl: 
          "https://jhhwacprwmysvxisckos.supabase.co/storage/v1/object/public/badge-icons/badge.png",
        progressType: "steps",
        progressValue: 1000,

      );
    } 
    //STEP CHAMPION (10,000 steps)
    if (stepsToday >= 10000){
      await badgeRepo.awardBadge(
        badgeName: "Step Champion",
        description: "walked 10,000 steps in one day!",
        iconUrl: "https://jhhwacprwmysvxisckos.supabase.co/storage/v1/object/public/badge-icons/trophy%20(1).png",
        progressType: "steps",
        progressValue: 10000,
      );
    }
  }
  //BADGE LOGIC FOR CALORIES
  Future<void> checkCaloriesBadges(int caloriesToday) async{
    if (caloriesToday >= 500){
      await badgeRepo.awardBadge(
        badgeName: "Calorie Crusher",
        description: "Burned 500 calories today!",
        iconUrl: "https://jhhwacprwmysvxisckos.supabase.co/storage/v1/object/public/badge-icons/fire.png",
        progressType: "calories",
        progressValue: 500,
      );
    }
  }
  //combine step + calorie badge checks
  Future<void> checkAllProgressBadges({
    required int stepsToday,
    required int caloriesToday,
  }) async {
    await checkStepBadges(stepsToday);
    await checkCaloriesBadges(caloriesToday);
  }
}
